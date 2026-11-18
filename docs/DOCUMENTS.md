# Document conventions

## Canonical sources

| Topic | Canonical source |
|---|---|
| Task content and status | Beads (`.beads/`, prefix `open-vpn`) |
| Decisions | `docs/adr/` |
| Requirements and change proposals | `openspec/` (after `openspec init`) |
| Runtime behavior | Source in `.docker/prod/` and `Makefile` |
| Agent instructions | `CLAUDE.md` and the global `AGENTS.md` |
| AI Factory configuration | `.ai-factory/` (after initialization) |

When a document and the source disagree, the source is correct; fix the document.

## Rules

- Write all documentation in English.
- Keep the root `README.md` a short landing page that links to `docs/`.
- Put topic pages in `docs/`; do not duplicate them at the root.
- Do not create task documents under `docs/tasks/`; tasks live in Beads.
- Do not write secrets, real IP addresses, or key material in documents.

## Locations

| Artifact | Path |
|---|---|
| ADR | `docs/adr/YYYY/MM/NNNN-short-title.md`, listed in `docs/adr/README.md` |
| Code review | `docs/reviews/YYYY/MM/NNNN-short-title.md` |
| Experiments | `docs/playground/` |
| References, research, roadmap, QA | Under `docs/`, created only when needed |
