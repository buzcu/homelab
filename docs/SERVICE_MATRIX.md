# Service matrix

Loopback ports are what Caddy proxies to; they are not reachable from the LAN
or the tailnet directly. A service is published only by giving it an entry in
`config/domains.yml`.

| Service | Loopback port | Persistent data | DB | Backed up by |
|---|---|---|---|---|
| Caddy | 80/443 (host net) | /srv/data/caddy | none | config.tgz (Caddyfile is generated) |
| Nextcloud AIO | 8080 admin, 11000 app | /srv/data/nextcloud-aio | AIO-managed | AIO's own Borg backup |
| Vaultwarden | 8081 | /srv/data/vaultwarden | SQLite | `.backup` + config.tgz |
| Home Assistant | 8123 (host net) | /srv/data/homeassistant | internal | config.tgz |
| Mosquitto | 1883 | /srv/data/mosquitto | none | config.tgz (conf is generated) |
| Zigbee2MQTT | 8087 | /srv/data/zigbee2mqtt | none | config.tgz |
| LLDAP | 17170 web, 3890 LDAP | /srv/data/lldap | SQLite | `.backup` + config.tgz |
| AdGuard | 3000 web, 53 DNS on LAN | /srv/data/adguard | none | config.tgz |
| Uptime Kuma | 3001 | /srv/data/uptime-kuma | SQLite | `.backup` + config.tgz |
| Paperless | 8000 | /srv/data/paperless | PostgreSQL + Redis | pg_dump + config.tgz |
| Stirling-PDF | 8082 | /srv/data/stirling-pdf | app-managed | config.tgz |
| Immich | 2283 | /srv/data/immich | PostgreSQL + Valkey | pg_dump; library via restic |
| Jellyfin | 8096 | /srv/data/jellyfin | app-managed | config.tgz |
| qBittorrent | 8085 | /srv/data/qbittorrent | none | config.tgz |
| Prowlarr | 9696 | /srv/data/prowlarr | SQLite | `.backup` + config.tgz |
| Radarr | 7878 | /srv/data/radarr | SQLite | `.backup` + config.tgz |
| Sonarr | 8989 | /srv/data/sonarr | SQLite | `.backup` + config.tgz |
| Calibre-Web | 8083 | /srv/data/calibre | SQLite | `.backup` + config.tgz |
| Odoo | 8069 | /srv/data/odoo | PostgreSQL | pg_dumpall + config.tgz |
| Forgejo | 3002 web, 2222 SSH | /srv/data/forgejo | SQLite (default) | `.backup` + config.tgz |

## Shared media library

qBittorrent, Radarr and Sonarr mount **one** path, `/srv/data/library` as
`/data`, so hardlinks work between downloads and the library:

| Host path | Seen as | Used by |
|---|---|---|
| /srv/data/library/downloads | /data/downloads | qBittorrent, Radarr, Sonarr |
| /srv/data/library/media | /data/media | Radarr, Sonarr; Jellyfin (`/media`, read-only) |
| /srv/data/library/books | /data/books | Calibre-Web (`/books`) |

Replicate this subtree with restic (`BACKUP_EXTRA_PATHS`); it is not in the
nightly snapshot.
