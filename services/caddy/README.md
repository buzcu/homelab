# caddy

The Caddyfile is **generated**. `scripts/render` builds
`/srv/data/caddy/Caddyfile` from `config/domains.yml` plus the upstream port
table in that script. Do not edit the generated file; the next render
overwrites it.

Only entries with a non-empty domain get a route, so an unconfigured service
can never break Caddy's startup — which is exactly what an unsubstituted
placeholder used to do.

Adding a service to the proxy takes three things:

1. a loopback port binding in the service's `compose.yml`
2. an entry in `config/domains.yml`
3. a line in the `ROUTES` table in `scripts/render`

Caddy runs on the host network, so it reaches every service's `127.0.0.1`
binding, and it owns ports 80 and 443. Nothing else may bind them.

With `ACME_EMAIL` empty, Caddy issues internal certificates only. Set it to
enable public ACME issuance — meaningful only for publicly resolvable names.
