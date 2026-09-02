# Production Homelab — Debian + Ansible + Docker Compose

A reproducible single-host homelab intended for a Debian 13 SFF server.

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
   deliberate and reviewable.
10. Every service has a separate Compose project and persistent directory.

## Repository layout

```text
bootstrap.sh
ansible/
  inventory.yml.example
  site.yml
  group_vars/all.yml.example
  roles/
config/
  services.yml
  domains.yml.example
  versions.yml
  secrets/
services/
  caddy/
  nextcloud-aio/
  vaultwarden/
  homeassistant/
  mosquitto/
  zigbee2mqtt/
  lldap/
  adguard/
  uptime-kuma/
  paperless/
  stirling-pdf/
  immich/
  jellyfin/
  qbittorrent/
  prowlarr/
  radarr/
  sonarr/
  calibre/
  odoo/
  forgejo/
scripts/
  deploy
  update-images
  backup
  healthcheck
backup/
  restic.env.example
```

## First installation

```bash
git clone <your-repository-url> /opt/homelab
cd /opt/homelab

cp ansible/inventory.yml.example ansible/inventory.yml
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml
cp config/domains.yml.example config/domains.yml
cp backup/restic.env.example backup/restic.env

# Review every file before running:
./bootstrap.sh
```

The bootstrap installs Ansible/Docker/Tailscale prerequisites and configures the
host. It does **not** automatically expose services to the public Internet.

Then:

```bash
sudo ./scripts/deploy core
sudo ./scripts/deploy documents
sudo ./scripts/deploy photos
sudo ./scripts/deploy media
sudo ./scripts/deploy business
```

Run `sudo ./scripts/deploy --help` for service-level deployment.

## Important operational rules

### Never edit generated state in `/srv/data` through Git

Application data is not configuration. Back it up with the application's
supported procedure and/or the repository backup scripts.

### Do not use `latest` for production

Images are pinned in `config/versions.yml`. Change a version deliberately,
read the upstream release notes, back up the relevant database, then deploy.

### Nextcloud AIO

Nextcloud AIO is special: its official deployment mechanism manages its own
component containers. The repository therefore manages the AIO mastercontainer
and its configuration, rather than pretending AIO is an ordinary single-image
Compose service.

### Home Assistant

Home Assistant Container is used because the host is already a Docker server.
It does not provide the Home Assistant OS add-on ecosystem. If add-ons are
important, move HA to its own VM/HAOS installation.

### Immich

Immich's PostgreSQL database must stay on local Unix-compatible storage, not a
network share. The repository separates the database path from the photo
library.

### Media stack

qBittorrent/Radarr/Sonarr/Prowlarr are not public services. Access them through
Tailscale. Use the stack only for content/indexers you are legally permitted to
use.

## Recovery target

A replacement Debian host should be recoverable by:

1. Install Debian.
2. Clone this repository.
3. Restore the Ansible Vault password/secret material.
4. Run `./bootstrap.sh`.
5. Restore application data/database backups.
6. Run the relevant `scripts/deploy` targets.
7. Validate with `scripts/healthcheck`.

The repository deliberately does not contain secrets or application data.
