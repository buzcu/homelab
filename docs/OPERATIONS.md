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

## Publishing to the Internet

The default posture is tailnet-only. Publishing takes four things, and missing
any one of them fails in a way that looks like a different problem:

1. **A name.** Put it in `config/domains.yml`. Only services with a non-empty
   entry get a Caddy route.
2. **`ACME_EMAIL`.** Left empty, Caddy issues internal (self-signed)
   certificates, which browsers reject. Set it to a mailbox you read; expiry
   warnings go there.
3. **Ports 80 and 443 forwarded** to this host on the router. Port 80 is not
   optional even if you only want HTTPS: Let's Encrypt's HTTP-01 challenge
   connects to it.
4. **`firewall_public_web: true`**, if `firewall_enabled` is also true.
   Otherwise the ruleset accepts 80/443 from `lan_cidr` only and every request
   from the Internet is dropped, including the ACME challenge.

Test with Let's Encrypt's staging CA first. A wrong port forward otherwise
burns the weekly rate limit for the name before anything works.

Publish only what is designed for it — Vaultwarden, Immich, Nextcloud,
Paperless all carry their own authentication. Leave LLDAP, AdGuard's admin
interface, Uptime Kuma, the media stack and the Nextcloud AIO admin interface
on the tailnet.

### Dynamic DNS

For a home connection with a changing IP, set `duckdns_enabled: true` in
`group_vars/all.yml` and fill in `DUCKDNS_DOMAIN` and `DUCKDNS_TOKEN` in
`config/secrets.env`. `homelab-duckdns.timer` then runs
`scripts/duckdns-update` a minute after boot and every five minutes after that.

The script reads `config/secrets.env` directly rather than the rendered
`/run/homelab/compose.env`, because the latter is on tmpfs and does not survive
a reboot. It treats DuckDNS's `KO` response as a failure, so a bad token puts
the unit into `failed` instead of looping quietly:

    systemctl status homelab-duckdns.service
    journalctl -u homelab-duckdns.service

Subdomains work without extra configuration: `*.<name>.duckdns.org` resolves to
the same address, so one DuckDNS name covers every service in
`config/domains.yml`. A wildcard *certificate* is a different matter — it needs
a DNS-01 challenge and a Caddy build that includes the DuckDNS provider, which
the pinned image does not have. Per-subdomain HTTP-01 certificates need none of
that and are what the generated Caddyfile asks for.

## Firewall

`roles/firewall` ships a real nftables ruleset, but `firewall_enabled` defaults
to `false`: a wrong `lan_cidr` locks you out of SSH. Enable it only once
Tailscale gives you a second way in.

The ruleset owns one table (`inet homelab`) and never flushes the ruleset, so
Docker's own netfilter rules survive a reload. It filters the input hook only;
published container ports traverse the forward hook, which Docker owns.

SSH and DNS are always restricted to `lan_cidr`; `firewall_public_web` widens
ports 80 and 443 only. DHCP client traffic is accepted explicitly — without it
a policy-drop input chain can leave the host unable to renew its lease, which
takes away the LAN path to SSH at the same moment.

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
