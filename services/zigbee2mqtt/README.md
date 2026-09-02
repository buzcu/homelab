# zigbee2mqtt

The frontend is on **8087**, not 8080: Nextcloud AIO owns 8080 and both are in
the `core` deployment group.

Zigbee2MQTT runs on the shared `homelab` network and reaches the broker at
`mqtt://mosquitto:1883`. A container cannot reach a service published on the
host's `127.0.0.1` — its own loopback is not the host's.

`scripts/render` seeds `/srv/data/zigbee2mqtt/configuration.yaml` once, with
the broker address, credentials and `ZIGBEE_DEVICE` from
`config/secrets.env`. Zigbee2MQTT rewrites that file at runtime, so render
never touches it again — edit it directly from then on.

Set `ZIGBEE_DEVICE` to a stable path, not `/dev/ttyUSB0`:

```bash
ls -l /dev/serial/by-id/
```
