# mosquitto

`mosquitto.conf` in this directory is the source. `scripts/render` installs it
to `/srv/data/mosquitto/config/mosquitto.conf` and generates the password file
next to it from `MOSQUITTO_USERNAME`/`MOSQUITTO_PASSWORD`. Editing the copy
under `/srv/data` is pointless — the next render overwrites it.

`allow_anonymous false` without a password file rejects every client, so the
two must be created together. `scripts/render` refuses to run if
`MOSQUITTO_PASSWORD` is empty.

Two ways in, on purpose:

- `127.0.0.1:1883` for Home Assistant, which runs on the host network.
- `mqtt://mosquitto:1883` on the shared `homelab` Docker network, for
  Zigbee2MQTT and any other container client.

Rotate the password by changing `config/secrets.env`, re-running
`sudo ./scripts/render`, then redeploying Mosquitto and every client.
