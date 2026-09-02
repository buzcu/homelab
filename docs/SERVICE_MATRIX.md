# Service matrix

| Service | Persistent data | DB | Public by default |
|---|---|---|---|
| Nextcloud AIO | /srv/data/nextcloud-aio | AIO-managed | No |
| Vaultwarden | /srv/data/vaultwarden | SQLite | No |
| Home Assistant | /srv/data/homeassistant | internal | No |
| Mosquitto | /srv/data/mosquitto | none | No |
| Zigbee2MQTT | /srv/data/zigbee2mqtt | none | No |
| LLDAP | /srv/data/lldap | SQLite | No |
| AdGuard | /srv/data/adguard | none | No |
| Uptime Kuma | /srv/data/uptime-kuma | SQLite | No |
| Paperless | /srv/data/paperless | PostgreSQL + Redis | No |
| Stirling-PDF | /srv/data/stirling-pdf | app-managed | No |
| Immich | /srv/data/immich | PostgreSQL + Valkey | No |
| Jellyfin | /srv/data/jellyfin | app-managed | No |
| qBittorrent | /srv/data/qbittorrent | none | No |
| Prowlarr | /srv/data/prowlarr | SQLite | No |
| Radarr | /srv/data/radarr | SQLite | No |
| Sonarr | /srv/data/sonarr | SQLite | No |
| Calibre-Web | /srv/data/calibre | SQLite | No |
| Odoo | /srv/data/odoo | PostgreSQL | No |
| Forgejo | /srv/data/forgejo | embedded / configurable | No |
