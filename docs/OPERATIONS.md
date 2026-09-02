# Operations

## Deployment

Validate first:

    sudo make validate

Deploy one service:

    sudo ./scripts/deploy vaultwarden

Deploy a category:

    sudo ./scripts/deploy media

## Updates

Do not blindly run `docker compose pull && up` on every service.

1. Read upstream release notes.
2. Update the version pin in `config/versions.yml` and/or the service Compose file.
3. Back up the affected application/database.
4. Run `docker compose config -q`.
5. Pull and recreate the service.
6. Check logs and application health.
7. Keep the previous version documented for rollback.

## Secrets

Secrets are not committed. Put service `.env` files under a protected location
or use Ansible Vault. For a small single-host installation, Ansible Vault is
a reasonable starting point.

Recommended permissions:

    chmod 600 *.env

## Network exposure

The default Compose files bind application ports to `127.0.0.1`. Caddy is the
only HTTP entry point intended to listen on the host. Home Assistant uses host
networking because this is the supported pattern for container deployments
where discovery integrations are required.

Do not port-forward qBittorrent/Radarr/Sonarr/Prowlarr to the Internet.

## Storage

Recommended layout:

    SSD:
      Debian
      Docker
      PostgreSQL
      application databases

    Large disk:
      /srv/data/immich/library
      /srv/data/media
      /srv/data/downloads
      /srv/data/books
      Nextcloud data

    Separate backup destination:
      /srv/backups
      and preferably a second physical machine/cloud target

## Disaster recovery

A backup is only useful if restore has been tested. Test restoration at least
once after the initial installation and after major architecture changes.
