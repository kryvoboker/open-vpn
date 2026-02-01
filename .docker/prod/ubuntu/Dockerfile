FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Kyiv

RUN apt update \
    && apt install -y --no-install-recommends \
        openvpn \
        easy-rsa \
        iptables \
        iproute2 \
        ca-certificates \
        bash \
        tzdata \
 && rm -rf /var/lib/apt/lists/*

# set time zone in container
RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime

RUN mkdir -p /etc/openvpn/pki /etc/openvpn/clients /etc/openvpn/easy-rsa

# Easy-RSA files (Ubuntu package)
RUN cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/

COPY .docker/prod/ubuntu/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 1194/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["openvpn", "--config", "/etc/openvpn/server.conf"]