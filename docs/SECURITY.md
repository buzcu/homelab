# Security model

- Remote administration: Tailscale.
- HTTP reverse proxy: Caddy, the only process intended to listen on the host.
- Databases: Docker-internal networking only.
- Application ports: loopback-bound by default.
- Public exposure: opt-in, one `config/domains.yml` entry at a time.
- Secrets: outside Git, mode 600, rendered to tmpfs.
- Updates: pinned, enforced by `scripts/check-versions`.
- Backups: verified, and replicated off-host by restic.

## Secrets

`config/secrets.env` and `backup/restic.env` are gitignored, created mode 600
by `bootstrap.sh`, and re-tightened by `scripts/render` if their mode drifts.
CI fails if either ever becomes a tracked file.

The merged Compose environment is written to `/run/homelab/compose.env` — tmpfs,
mode 600, regenerated on every deploy, gone after a reboot. No file containing
a secret is written inside the Git working tree.

## SSH

Password authentication is disabled only when `harden_ssh: true`. Confirm a
key-based session works in a second terminal first — the handler reloads sshd
rather than restarting it, so existing sessions survive a mistake, but new
password logins will be refused for good.

## Firewall

`firewall_enabled` (default `false`) controls a real nftables ruleset. See
docs/OPERATIONS.md for why it is opt-in and how to recover from a lockout.

Note what the ruleset does *not* do: Docker publishes ports by DNAT through the
forward hook, which Docker owns. Filtering the input hook does not close a
published container port. Binding services to `127.0.0.1` is what closes them,
and that remains the primary control.

## Container privilege

- Home Assistant runs with host networking but **not** `privileged`. Privileged
  is effectively host root; grant individual devices instead.
- Radarr, Sonarr and qBittorrent see `/srv/data/library`, not all of
  `/srv/data`. Prowlarr sees only its own config directory.
- Nextcloud AIO mounts the Docker socket. `:ro` is the documented upstream
  pattern, but be clear-eyed: Docker socket access is root-equivalent on this
  host regardless of that flag. It is the price of running AIO.

## Authentication

Mosquitto sets `allow_anonymous false` **and** ships a password file generated
by `scripts/render` from `MOSQUITTO_USERNAME`/`MOSQUITTO_PASSWORD`. Without the
password file, `allow_anonymous false` rejects every client, including
Zigbee2MQTT and Home Assistant.

Vaultwarden has `SIGNUPS_ALLOWED=false`. Its `DOMAIN` must be the full external
URL — Bitwarden clients, WebAuthn and invitation links fail quietly if it is
wrong or empty, so the Compose file refuses to start without it.

## Tailscale

Use the tailnet ACL/device posture controls for access to administration and
private applications. Avoid making the whole tailnet implicitly trusted.
