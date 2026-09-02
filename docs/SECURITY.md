# Security model

- Remote administration: Tailscale.
- HTTP reverse proxy: Caddy.
- Databases: Docker-internal networking only.
- Application ports: loopback-bound by default.
- Public exposure: opt-in.
- Secrets: outside Git.
- Updates: pinned and deliberate.
- Backups: separate destination required.

## SSH

The Ansible role does not disable password SSH automatically. First confirm
that a second SSH session works using a key. Only then enable the optional SSH
hardening role/variables you add for your environment.

## Docker

Docker's networking rules interact with nftables. Do not assume a generic UFW
rule set protects published Docker ports. The safest default here is to avoid
publishing application ports at all and bind them to localhost.

## Tailscale

Use the tailnet ACL/device posture controls for access to administration and
private applications. Avoid making the whole tailnet implicitly trusted.
