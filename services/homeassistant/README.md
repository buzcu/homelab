# homeassistant

Container mode is intentional. It does not provide HA OS add-ons.

Host networking is kept because discovery integrations (mDNS, SSDP) need it.
`privileged: true` is **not** used: it grants effective host root, and almost
nothing in HA actually requires it. Add the specific device an integration
needs instead, in `compose.yml`:

```yaml
devices:
  - /dev/serial/by-id/usb-0658_0200-if00:/dev/ttyACM0   # Z-Wave stick
```

Bluetooth works through the `/run/dbus` mount that is already present.

MQTT: point the integration at `127.0.0.1:1883` with the credentials from
`MOSQUITTO_USERNAME`/`MOSQUITTO_PASSWORD` in `config/secrets.env`. HA is on the
host network, so loopback reaches the broker's published port.
