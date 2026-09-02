# Nextcloud AIO

This uses the official Nextcloud AIO mastercontainer. AIO manages its own
PostgreSQL/Redis/Nextcloud/Office/etc. component containers.

The admin interface binds to `AIO_BIND_ADDRESS` (default `127.0.0.1`), not to
every interface. Reach it with an SSH tunnel:

    ssh -L 8080:127.0.0.1:8080 <host>

or set `AIO_BIND_ADDRESS` to this host's Tailscale IP in `config/secrets.env`.

AIO is the one service allowed to run `:latest`: the mastercontainer
self-updates and upstream supports no other tag. It pins its own component
containers. `scripts/check-versions` exempts it by name.

After deployment:

1. Open `https://127.0.0.1:8080` through the tunnel.
2. Follow the AIO onboarding.
3. Configure the chosen Nextcloud domain.
4. Configure the external Caddy reverse proxy according to the current AIO
   reverse-proxy documentation.
5. Enable Nextcloud Office / the Euro-Office option if it is available in the
   AIO release you are running.

Do not add a second PostgreSQL/Redis stack for Nextcloud.
