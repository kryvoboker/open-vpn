#!/usr/bin/env bash
set -euo pipefail

# Apply umask for runtime
umask "${UMASK:-0002}"

PKI_DIR="/etc/openvpn/pki"
CLIENTS_DIR="/etc/openvpn/clients"

EASYRSA_BIN=""

mkdir -p "${PKI_DIR}" "${CLIENTS_DIR}"

resolve_easyrsa_bin() {
  if command -v easyrsa >/dev/null 2>&1; then
    command -v easyrsa
    return
  fi

  for p in /usr/share/easy-rsa/easyrsa /usr/share/easy-rsa/easyrsa3/easyrsa; do
    if [[ -x "$p" ]]; then
      echo "$p"
      return
    fi
  done

  return 1
}

EASYRSA_BIN="$(resolve_easyrsa_bin)" || {
  echo "[openvpn] easyrsa not found (expected in /usr/share/easy-rsa)"
  exit 1
}

for p in /usr/share/easy-rsa/easyrsa /usr/share/easy-rsa/easyrsa3/easyrsa; do
  if [[ -x "$p" ]]; then
    EASYRSA_BIN="$p"
    break
  fi
done

if [[ -z "$EASYRSA_BIN" ]]; then
  echo "[openvpn] easyrsa not found in /usr/share/easy-rsa"
  exit 1
fi

: "${OVPN_HOST:?Set OVPN_HOST (public domain or IP) in docker-compose.yml}"
: "${OVPN_PORT:=1194}"
: "${OVPN_PROTO:=udp}"

init_pki_if_needed() {
  # Check if PKI already initialized by verifying key files exist
  if [[ -f "${PKI_DIR}/ca.crt" && -f "${PKI_DIR}/issued/server.crt" && -f "${PKI_DIR}/private/server.key" && -f "${PKI_DIR}/dh.pem" ]]; then
    echo "[openvpn] PKI exists, skipping init."
    return
  fi

  echo "[openvpn] Initializing PKI..."

  # Only initialize if pki directory is empty or missing critical files
  if [[ ! -d "${PKI_DIR}" ]] || [[ -z "$(ls -A ${PKI_DIR} 2>/dev/null)" ]]; then
    "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" init-pki
  else
    echo "[openvpn] PKI directory exists but incomplete, cleaning up..."
    rm -rf "${PKI_DIR}"/* "${PKI_DIR}"/.[!.]* "${PKI_DIR}"/..?* 2>/dev/null || true
    "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" init-pki
  fi

  # CA (no password for automation)
  "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" build-ca nopass

  # Server cert
  "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" build-server-full server nopass

  # Generate DH parameters
  echo "[openvpn] Generating DH parameters (this may take a while)..."
  "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" gen-dh

  # CRL
  "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" gen-crl

  # tls-crypt key
  openvpn --genkey secret "${PKI_DIR}/tls-crypt.key"

  chmod 600 "${PKI_DIR}/private/server.key" "${PKI_DIR}/tls-crypt.key" || true

  echo "[openvpn] PKI initialized."
}

ensure_ip_forwarding() {
  # container sysctl is set via docker-compose, but keep a guard
  if [[ -f /proc/sys/net/ipv4/ip_forward ]]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward || true
  fi
}

ensure_nat_rules() {
  # Determine default outbound interface
  local wan_if
  wan_if="$(ip route show default 0.0.0.0/0 | awk '{print $5}' | head -n1)"
  if [[ -z "${wan_if}" ]]; then
    echo "[openvpn] Cannot detect WAN interface."
    exit 1
  fi

  # NAT for VPN clients to access internet through server (MASQUERADE)
  if ! iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "${wan_if}" -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "${wan_if}" -j MASQUERADE
  fi

  # Allow forwarding between tun and WAN
  if ! iptables -C FORWARD -i tun0 -o "${wan_if}" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i tun0 -o "${wan_if}" -j ACCEPT
  fi
  if ! iptables -C FORWARD -i "${wan_if}" -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "${wan_if}" -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
  fi
}

print_client_hint() {
  cat <<EOF
[openvpn] To generate a client profile:
  docker exec -it openvpn /entrypoint.sh gen-client <client_name>

Then find the file in ./clients/<client_name>.ovpn
EOF
}

gen_client() {
  local client_name="${1:-}"
  if [[ -z "${client_name}" ]]; then
    echo "Usage: gen-client <client_name>"
    exit 1
  fi

  # build client cert
  "$EASYRSA_BIN" --batch --pki-dir="${PKI_DIR}" build-client-full "${client_name}" nopass

  local client_ovpn="/etc/openvpn/clients/${client_name}.ovpn"

  cat > "${client_ovpn}" <<EOF
client
dev tun
proto ${OVPN_PROTO}
remote ${OVPN_HOST} ${OVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
tls-version-min 1.2
verb 3

data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM

<ca>
$(cat "${PKI_DIR}/ca.crt")
</ca>

<cert>
$(awk '/BEGIN CERTIFICATE/{flag=1} flag{print} /END CERTIFICATE/{flag=0}' "${PKI_DIR}/issued/${client_name}.crt")
</cert>

<key>
$(cat "${PKI_DIR}/private/${client_name}.key")
</key>

<tls-crypt>
$(cat "${PKI_DIR}/tls-crypt.key")
</tls-crypt>
EOF

  echo "[openvpn] Client profile generated: ${client_ovpn}"
}

case "${1:-}" in
  gen-client)
    init_pki_if_needed
    gen_client "${2:-}"
    exit 0
    ;;
esac

init_pki_if_needed
#ensure_ip_forwarding
ensure_nat_rules
print_client_hint

exec "$@"