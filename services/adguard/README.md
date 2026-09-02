# adguard

`ADGUARD_DNS_BIND` in `config/secrets.env` must be a real address of this host.
It is not hardcoded, so this repository stays portable between machines.

Two things to sort out before deploying:

1. **systemd-resolved usually holds :53.** Free it first — set
   `DNSStubListener=no` in `/etc/systemd/resolved.conf`, then
   `systemctl restart systemd-resolved`.
2. **Keep the admin interface on port 3000** during onboarding. AdGuard's
   wizard suggests moving it to 80, but Caddy owns 80 on the host network.
   Only 3000 is published, and that is what `config/domains.yml` proxies.
