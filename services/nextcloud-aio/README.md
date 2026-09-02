# Nextcloud AIO

This uses the official Nextcloud AIO mastercontainer. AIO manages its own
PostgreSQL/Redis/Nextcloud/Office/etc. component containers.

After deployment:

1. Open `https://HOST:8080` from the LAN.
2. Follow the AIO onboarding.
3. Configure the chosen Nextcloud domain.
4. Configure the external Caddy reverse proxy according to the current AIO
   reverse-proxy documentation.
5. Enable Nextcloud Office / the Euro-Office option if it is available in the
   AIO release you are running.

Do not add a second PostgreSQL/Redis stack for Nextcloud.
