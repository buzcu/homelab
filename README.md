# Production Homelab — Debian + Ansible + Docker Compose

A reproducible single-host homelab intended for a Debian 13 SFF server.

> **Status:** the image tags in `config/versions.yml` are the ones this
> repository was written against. Validate them in your own environment before
> the first production deployment.

## Design goals

1. **Git is the source of truth** for host configuration, Compose definitions,
   service enablement and non-secret configuration.
2. **Ansible configures the host**; Docker Compose runs applications.
3. **No database ports are published** to the LAN unless explicitly required.
4. **Tailscale is the default remote-access path.**
5. **Caddy is the reverse proxy** for HTTP applications.
6. **Persistent data lives under `/srv/data`**, preferably on a dedicated SSD/HDD.
7. **Databases stay on local SSD storage**.
8. **Backups are separate from the server**. Local backup staging is not a backup
   until it is replicated to another device/location.
9. **Images are version-pinned** through `config/versions.yml`; upgrades are
   deliberate and reviewable. `scripts/check-versions` enforces that the pins
   and the Compose files agree.
10. Every service has a separate Compose project and persistent directory.
11. **Secrets never enter Git.** They live in `config/secrets.env` (gitignored,
    mode 600) and are rendered into `/run/homelab/compose.env` on tmpfs.

## Repository layout

```text
bootstrap.sh
ansible/
  inventory.yml.example
  requirements.yml
  site.yml
  group_vars/all.yml.example
  roles/
config/
  services.yml          the service catalogue: category, enablement, upstream
  versions.yml          authoritative image pins
  domains.yml.example   reverse-proxy hostnames (host-specific, gitignored)
  secrets.env.example   passwords, keys, host-specific paths
services/
  <one directory per service, each with its own compose.yml>
scripts/
  render                generates the Compose env, Caddyfile, service configs
  deploy                validate -> pull -> up, per service or category
  check-versions        image pins vs. Compose files
  update-images         pre-pull without recreating anything
  backup                verified nightly snapshot + restic replication
  healthcheck           host/service health, non-zero exit on problems
  lib/common.sh
backup/
  restic.env.example
```

## First installation

```bash
git clone <your-repository-url> /opt/homelab
cd /opt/homelab
sudo ./bootstrap.sh
```

`bootstrap.sh` installs the prerequisites, seeds the host-specific files from
their `.example` counterparts, and runs the Ansible play. It does **not**
expose anything to the public Internet.

Then fill in the generated files — every empty value in `config/secrets.env`
is required:

```bash
sudo tailscale up
sudoedit /opt/homelab/config/secrets.env    # openssl rand -base64 36
sudoedit /opt/homelab/config/domains.yml
sudo ./scripts/render
sudo make validate
```

And deploy:

```bash
sudo ./scripts/deploy core
sudo ./scripts/deploy documents
sudo ./scripts/deploy photos
sudo ./scripts/deploy media
sudo ./scripts/deploy books
sudo ./scripts/deploy business
```

`scripts/deploy` runs `scripts/render` first, skips anything switched off in
`config/services.yml`, and validates every Compose file before starting any of
them. Run `sudo ./scripts/deploy --help` for service-level deployment.

## How configuration flows

```text
config/services.yml ─┐   (catalogue: category, enabled, upstream, backup scope)
config/domains.yml  ─┤   (host-specific hostnames)
config/secrets.env  ─┼─> scripts/render ─┬─> /run/homelab/compose.env  (tmpfs, 600)
config/versions.yml ─┘                   ├─> /srv/data/caddy/Caddyfile
                                         ├─> /srv/data/mosquitto/config/{mosquitto.conf,passwd}
                                         └─> /srv/data/zigbee2mqtt/configuration.yaml (seeded once)
```

`config/services.yml` is the single structural source. The deploy categories,
the Caddy routes and the directories `scripts/backup` archives are all derived
from it, so none of them can drift apart — adding a service means a Compose
directory and one catalogue entry, never a change to a script.

Compose files are never run without `--env-file /run/homelab/compose.env`;
`scripts/deploy`, `scripts/update-images` and `make validate` all pass it.
A bare `docker compose -f services/x/compose.yml up` will fail on purpose.

## Important operational rules

### Never edit generated state in `/srv/data` through Git

Application data is not configuration. Back it up with the application's
supported procedure and/or the repository backup scripts.

Two files under `/srv/data` are generated and **will be overwritten** by
`scripts/render`: the Caddyfile and the Mosquitto config. Edit their sources in
this repository instead.

### Do not use `latest` for production

Images are pinned in `config/versions.yml` and repeated in each Compose file;
`scripts/check-versions` fails if the two disagree, so they cannot drift.
Nextcloud AIO is the one allowed exception, for the reason below.

### Storage layout

Persistent state lives in `/srv/data/<service>`. The media stack is different:
qBittorrent, Radarr and Sonarr share a single `/srv/data/library:/data` mount
containing `downloads/`, `media/` and `books/`.

One mount, not several, is what makes hardlinks possible — `link()` across two
separate bind mounts fails with `EXDEV` even on the same filesystem. Scoping it
to `library/` also keeps Vaultwarden, Paperless, Immich and LLDAP out of reach
of those containers.

### Nextcloud AIO

Nextcloud AIO is special: its official deployment mechanism manages its own
component containers, self-updates, and is supported on `:latest` only. The
repository therefore manages the AIO mastercontainer and its configuration,
rather than pretending AIO is an ordinary single-image Compose service. Its
admin interface binds to `AIO_BIND_ADDRESS` (loopback by default) — reach it
over an SSH tunnel or set the host's Tailscale IP.

### Home Assistant

Home Assistant Container is used because the host is already a Docker server.
It does not provide the Home Assistant OS add-on ecosystem. If add-ons are
important, move HA to its own VM/HAOS installation.

It runs with host networking but **not** privileged. Add the specific devices
an integration needs; see `services/homeassistant/README.md`.

### Immich

Immich's PostgreSQL database must stay on local Unix-compatible storage, not a
network share. `IMMICH_DB_DATA_LOCATION` and `IMMICH_UPLOAD_LOCATION` in
`config/secrets.env` keep the database path separate from the photo library.

### Media stack

qBittorrent/Radarr/Sonarr/Prowlarr are not public services. Access them through
Tailscale. Use the stack only for content/indexers you are legally permitted to
use.

## Recovery target

A replacement Debian host should be recoverable by:

1. Install Debian.
2. Clone this repository.
3. Restore `config/secrets.env` and `backup/restic.env` from your password
   manager or Ansible Vault — they are deliberately not in Git.
4. Run `sudo ./bootstrap.sh`.
5. Restore application data/database backups (`scripts/backup` output, or the
   restic repository).
6. Run `sudo ./scripts/render`, then the relevant `scripts/deploy` targets.
7. Validate with `sudo ./scripts/healthcheck` — it exits non-zero if anything
   is wrong.

The repository deliberately contains no secrets and no application data.
