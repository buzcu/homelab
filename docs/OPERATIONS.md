# Operations

## Deployment

Regenerate host configuration and validate first:

    sudo ./scripts/render
    sudo make validate

`make validate` runs two checks: `scripts/check-versions` (image pins match the
Compose files) and `docker compose config -q` for every service. Both collect
all failures rather than stopping at the first, and both fail the build.

Deploy one service:

    sudo ./scripts/deploy vaultwarden

Deploy a category:

    sudo ./scripts/deploy media

Deploy something switched off in `config/services.yml`:

    sudo ./scripts/deploy --force jellyfin

`scripts/deploy` renders configuration, validates *every* target before
starting *any* of them, then pulls and recreates each in turn.

## Updates

Do not blindly run `docker compose pull && up` on every service.

1. Read upstream release notes.
2. Update the tag in **both** `config/versions.yml` and the service's
   `compose.yml`. `scripts/check-versions` fails if you change only one.
3. Back up the affected application/database: `sudo ./scripts/backup`.
4. `sudo make validate`
5. `sudo ./scripts/deploy <service>`
6. Check logs and application health: `sudo ./scripts/healthcheck`
7. Keep the previous version documented for rollback — the previous tag is in
   the Git history of `config/versions.yml`.

`sudo ./scripts/update-images` pre-pulls the pinned images without recreating
anything. It never changes a pin.

## Secrets

Secrets are not committed; `.gitignore` enforces it and CI fails if a secrets
file ever becomes tracked.

- `config/secrets.env` — passwords, keys, host-specific paths. Mode 600.
- `backup/restic.env` — restic repository and password. Mode 600.

`scripts/render` merges `config/secrets.env` with `config/domains.yml` and
writes `/run/homelab/compose.env` (mode 600, on tmpfs, regenerated on every
deploy and gone after a reboot). Nothing containing a secret is written inside
the Git working tree.

For a small single-host installation this is enough. Ansible Vault is a
reasonable next step if you want the secrets themselves versioned.

Generate values with:

    openssl rand -base64 36

## Network exposure

Compose files bind application ports to `127.0.0.1`. Caddy is the only HTTP
entry point intended to listen on the host. Home Assistant uses host networking
because this is the supported pattern for container deployments where discovery
integrations are required.

Because everything else is on loopback, **a service without an entry in
`config/domains.yml` is not reachable at all** — not from the LAN and not from
the tailnet. That is the intended default. Give a service a domain to publish
it through Caddy.

Two ports are deliberately configurable rather than loopback-only:

- `AIO_BIND_ADDRESS` — the Nextcloud AIO admin interface.
- `FORGEJO_SSH_BIND` — git-over-SSH, unreachable from the tailnet on 127.0.0.1.

Set them to the host's Tailscale IP if you need tailnet access.

Do not port-forward qBittorrent/Radarr/Sonarr/Prowlarr to the Internet.

## Firewall

`roles/firewall` ships a real nftables ruleset, but `firewall_enabled` defaults
to `false`: a wrong `lan_cidr` locks you out of SSH. Enable it only once
Tailscale gives you a second way in.

The ruleset owns one table (`inet homelab`) and never flushes the ruleset, so
Docker's own netfilter rules survive a reload. It filters the input hook only;
published container ports traverse the forward hook, which Docker owns.

If you do lock yourself out, from a physical console:

    nft delete table inet homelab

## Storage

Recommended layout:

    SSD:
      Debian
      Docker
      PostgreSQL
      application databases          /srv/data/*/postgres

    Large disk:
      /srv/data/immich/library
      /srv/data/library/{media,downloads,books}
      /srv/data/nextcloud-aio/ncdata
      /srv/data/paperless/media

    Separate backup destination:
      /srv/backups
      and preferably a second physical machine/cloud target

If you point `data_device` at a disk that does not exist, the play now fails
instead of silently leaving everything on the system disk.

## Backups

`scripts/backup` runs nightly via `homelab-backup.timer` (03:30) and:

- takes verified logical PostgreSQL dumps (Immich, Paperless, and a
  cluster-wide `pg_dumpall` for Odoo, which uses one database per Odoo database)
- takes consistent SQLite copies with `.backup`, never a raw copy of a live file
- archives configuration directories and the repository at `HEAD`
- replicates to restic when `backup/restic.env` exists
- keeps the newest 14 snapshot directories

Every step is checked. A dump that is missing, unreadable or suspiciously small
is an error, and any error makes the whole run exit non-zero so the systemd
unit lands in `failed` instead of reporting success over an empty snapshot.

Check on it:

    systemctl status homelab-backup.service
    cat /srv/backups/.last-status
    sudo ./scripts/healthcheck        # also flags a stale or failed backup

Deliberately **not** in the nightly snapshot, because they are too large to
re-archive every night — hand them to restic via `BACKUP_EXTRA_PATHS`:

- `/srv/data/immich/library`, `/srv/data/library`, `/srv/data/paperless/media`

Nextcloud AIO is not covered either: it has its own supported Borg backup in
the AIO admin interface. Use it.

## Disaster recovery

A backup is only useful if restore has been tested. Test restoration at least
once after the initial installation and after major architecture changes.

    zcat /srv/backups/<stamp>/paperless.sql.gz | \
      docker exec -i paperless-db-1 psql -U paperless paperless
