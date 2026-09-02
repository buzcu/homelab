# caddy

The Caddyfile is **generated**. `scripts/render` builds
`/srv/data/caddy/Caddyfile` by joining the service catalogue in
`config/services.yml` (which port to proxy to, and whether the service is
enabled at all) with the hostnames in `config/domains.yml`. Do not edit the
generated file; the next render overwrites it.

The split is deliberate: `config/services.yml` is committed and structural,
while hostnames are host-specific and belong in the gitignored file, so nobody's
personal domains end up in the repository.

A route is emitted only when all three hold — the service is enabled, it
declares an `upstream`, and it has a non-empty hostname. Anything else is
skipped with a warning naming the reason, so a missing route is never silent
and an unconfigured service can never break Caddy's startup.

Adding a service to the proxy takes two edits and no script change:

1. an `upstream:` in that service's `config/services.yml` entry, matching the
   loopback binding in its `compose.yml`
2. a hostname in `config/domains.yml`

Caddy runs on the host network, so it reaches every service's `127.0.0.1`
binding, and it owns ports 80 and 443. Nothing else may bind them.

With `ACME_EMAIL` empty, Caddy issues internal certificates only. Set it to
enable public ACME issuance — meaningful only for publicly resolvable names.
