# radarr

Mounts `/srv/data/library` as `/data`, exactly like qBittorrent and Sonarr.

One mount, not two, is deliberate: `link()` across separate bind mounts fails
with `EXDEV` even when both sit on the same filesystem, which silently turns
every "hardlink" import into a full copy. Configure Radarr's root folder as
`/data/media` and qBittorrent's download directory as `/data/downloads`.

The mount is scoped to `library/` rather than all of `/srv/data`, so this
container cannot read Vaultwarden, Paperless, Immich or LLDAP data.
