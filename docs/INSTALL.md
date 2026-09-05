# Installing on a fresh Debian host

A runbook for a first installation. Follow it in order: each phase leaves the
host in a working state, and the risky steps (public exposure, the firewall)
come last, once there is something known-good to fall back to.

Everything here runs **on the server itself**. The Ansible inventory uses
`ansible_connection: local`; there is no remote-provisioning path.

## Before you start

Three decisions, because changing them later is expensive:

**Where the data lives.** If you have a second disk for `/srv/data`, partition
and format it *now*. Ansible mounts it before it creates any directory, so
setting it up afterwards means moving data by hand.

**Your LAN subnet.** Needed for the firewall rules. Find it with:

```bash
ip -4 -br addr show scope global
```

An address of `192.168.1.42/24` means `lan_cidr: 192.168.1.0/24`.

**Which services face the Internet.** Publishing is per-service and opt-in.
Vaultwarden, Immich, Nextcloud and Paperless all carry their own
authentication and are reasonable to publish. LLDAP, Uptime Kuma, the AdGuard
admin interface, the media stack and the Nextcloud AIO admin interface should
stay on the tailnet.

## 1. Base system

Install Debian 13 with SSH, add your user to `sudo`, and copy in your SSH key.
Then:

```bash
sudo apt-get update && sudo apt-get install -y git
```

## 2. Clone to /opt/homelab

The path is not arbitrary: `homelab-backup.service` and
`homelab-duckdns.service` both hardcode `/opt/homelab`, and the Ansible base
role creates that directory.

```bash
sudo git clone https://github.com/buzcu/homelab /opt/homelab
```

## 3. Write the configuration

Do this **before** `bootstrap.sh`. Bootstrap seeds any of these files that is
missing from its `.example`, and skips ones that already exist — so writing
them first means the very first Ansible run already has your values, including
`data_device`.

### ansible/group_vars/all.yml

Adjust `lan_cidr`, and `data_device` if you have a dedicated disk. Leave the
firewall and DuckDNS switches off for now; they are turned on in phases 9
and 10, once there is a working system to protect.

```bash
sudo tee /opt/homelab/ansible/group_vars/all.yml > /dev/null <<'EOF'
homelab_timezone: Europe/Amsterdam
homelab_user: homelab

docker_data_root: /var/lib/docker
data_root: /srv/data
backup_root: /srv/backups

# Dedicated data disk. Leave "" to keep everything on the system disk.
# A device that does not exist now fails the play instead of silently
# leaving all data on the root filesystem.
data_device: ""
data_mount: /srv/data
data_filesystem: ext4

# Turn on only after confirming a key-based SSH session works.
harden_ssh: false

# CHANGE THIS to your LAN.
lan_cidr: 192.168.1.0/24
tailscale_interface: tailscale0

# Enabled in phase 10, not before.
firewall_enabled: false
firewall_public_web: false

# Enabled in phase 9, not before.
duckdns_enabled: false
EOF
```

### config/domains.yml

Keys are service directory names. A service gets a Caddy route only when it is
enabled, declares an `upstream` in `config/services.yml`, and has a non-empty
hostname here — anything else is skipped with a warning saying which of the
three applies.

Two kinds of name, deliberately mixed:

- **DuckDNS names resolve publicly.** `*.buzcu.duckdns.org` all point at your
  home IP, so anything you name here becomes reachable from the Internet once
  ports 80/443 are forwarded.
- **MagicDNS names (`*.ts.net`) resolve only inside your tailnet.** That is how
  a service stays private while still going through Caddy.

Start with everything blank except what you intend to publish. Fill in the
tailnet names in phase 7, once `tailscale status` has told you your tailnet's
domain.

```bash
sudo tee /opt/homelab/config/domains.yml > /dev/null <<'EOF'
domains:
  # Public, through DuckDNS.
  vaultwarden: vault.buzcu.duckdns.org
  immich: photos.buzcu.duckdns.org
  paperless: paperless.buzcu.duckdns.org
  nextcloud-aio: cloud.buzcu.duckdns.org

  # Tailnet-only. Fill in with MagicDNS names after phase 5:
  #   uptime-kuma: status.<your-tailnet>.ts.net
  #   lldap:       ldap.<your-tailnet>.ts.net
  homeassistant: ""
  lldap: ""
  uptime-kuma: ""
  stirling-pdf: ""

  # Disabled in config/services.yml. Fill in when you enable the service.
  zigbee2mqtt: ""
  adguard: ""
  jellyfin: ""
  qbittorrent: ""
  prowlarr: ""
  radarr: ""
  sonarr: ""
  calibre: ""
  odoo: ""
  forgejo: ""
EOF
```

> `paperless` must have a hostname: its Compose file requires `PAPERLESS_DOMAIN`
> and refuses to validate without one. If you do not want Paperless reachable
> yet, disable it in `config/services.yml` instead of blanking its hostname.

### config/secrets.env

**Generate these on the server.** Secrets that pass through a chat window, a
clipboard, or a note-taking app should be considered disclosed.

Values are hex rather than base64 on purpose: hex has no `+`, `/` or `=`, so
the same string survives an env file, a YAML seed and `mosquitto_passwd`
without any quoting surprises.

Fill in `DUCKDNS_TOKEN` from your DuckDNS account page afterwards.

Note `CADDY_ACME_CA`: the first deployment uses Let's Encrypt's **staging**
directory. Browsers will reject a staging certificate — that is expected, and
it means a wrong port forward cannot burn the production rate limit for your
name. Phase 9 switches it off.

```bash
sudo tee /opt/homelab/config/secrets.env > /dev/null <<EOF
# --- Caddy ---
ACME_EMAIL=gorkem.buzcu@gmail.com
CADDY_ACME_CA=https://acme-staging-v02.api.letsencrypt.org/directory

# --- DuckDNS --- (paste the token from duckdns.org)
DUCKDNS_DOMAIN=buzcu
DUCKDNS_TOKEN=

# --- Nextcloud AIO ---
AIO_BIND_ADDRESS=127.0.0.1

# --- Vaultwarden --- (derived from domains.yml when left empty)
VAULTWARDEN_URL=

# --- LLDAP ---
LLDAP_JWT_SECRET=$(openssl rand -hex 32)
LLDAP_LDAP_USER_PASS=$(openssl rand -hex 24)
LLDAP_LDAP_BASE_DN=dc=home,dc=arpa

# --- Mosquitto ---
MOSQUITTO_USERNAME=homelab
MOSQUITTO_PASSWORD=$(openssl rand -hex 24)

# --- Zigbee2MQTT --- (disabled; real path goes here when you enable it)
ZIGBEE_DEVICE=/dev/null

# --- AdGuard --- (disabled; a real host address goes here when you enable it)
ADGUARD_DNS_BIND=127.0.0.1

# --- Paperless ---
PAPERLESS_DB_PASSWORD=$(openssl rand -hex 24)
PAPERLESS_SECRET_KEY=$(openssl rand -hex 32)

# --- Immich ---
IMMICH_DB_PASSWORD=$(openssl rand -hex 24)
IMMICH_UPLOAD_LOCATION=/srv/data/immich/library
IMMICH_DB_DATA_LOCATION=/srv/data/immich/postgres

# --- Odoo --- (disabled, but \`make validate\` checks every Compose file)
ODOO_DB_PASSWORD=$(openssl rand -hex 24)

# --- Forgejo ---
FORGEJO_SSH_BIND=127.0.0.1

TZ=Europe/Amsterdam
EOF
```

Then lock it down and add your DuckDNS token:

```bash
sudo chmod 600 /opt/homelab/config/secrets.env && sudo chown root:root /opt/homelab/config/secrets.env
```

```bash
sudo nano /opt/homelab/config/secrets.env
```

> Every variable above is required even for services that are switched off,
> because `make validate` checks every Compose file, not just the enabled ones.
> `ODOO_DB_PASSWORD`, `ADGUARD_DNS_BIND` and `ZIGBEE_DEVICE` are there for that
> reason.

## 4. Bootstrap

Installs Docker, Ansible, Tailscale and the host packages, creates
`/srv/data`, and installs the backup timer. It exposes nothing.

```bash
cd /opt/homelab && sudo ./bootstrap.sh
```

## 5. Join the tailnet

Prints a URL to open in a browser.

```bash
sudo tailscale up
```

Then note your MagicDNS domain — the `.ts.net` suffix in the output is what
goes into the tailnet-only entries of `config/domains.yml`:

```bash
tailscale status
```

## 6. Render and validate

`render` writes the Compose environment, the Caddyfile, and the Mosquitto
config and password file. It also proves your secrets parse and that the
generated Caddyfile is valid before anything starts.

```bash
sudo /opt/homelab/scripts/render
```

```bash
cd /opt/homelab && sudo make validate
```

`make validate` runs two checks: that every image pin matches
`config/versions.yml` and that the service catalogue matches the `services/`
directories, then `docker compose config` on every service.

## 7. Deploy

Validates every target before starting any of them, and skips whatever is
disabled in `config/services.yml`.

```bash
sudo /opt/homelab/scripts/deploy core
```

```bash
sudo /opt/homelab/scripts/deploy documents
```

```bash
sudo /opt/homelab/scripts/deploy photos
```

Then check the result. It exits non-zero if anything is wrong:

```bash
sudo /opt/homelab/scripts/healthcheck
```

## 8. First-run setup, per service

Everything is on loopback, so reach the admin interfaces over an SSH tunnel
until the tailnet names are in place.

**Nextcloud AIO** — its admin interface is deliberately not on the LAN:

```bash
ssh -L 8080:127.0.0.1:8080 <your-host>
```

Then open `https://127.0.0.1:8080` and follow the AIO onboarding. Do not add a
second PostgreSQL or Redis for Nextcloud; AIO manages its own.

**Vaultwarden** — `SIGNUPS_ALLOWED=false` is already set. Create your account
through an invitation from the admin page rather than opening signups.

**Immich, Paperless** — first visit creates the admin account. Do that before
they are reachable from the Internet.

## 9. Going public

Only after the above works.

1. **Forward ports 80 and 443** to this host on your router. Port 80 is not
   optional even if you only want HTTPS: Let's Encrypt's HTTP-01 challenge
   connects to it.

2. **Turn on the DuckDNS updater** so a changing home IP does not break every
   name and every renewal. Set `duckdns_enabled: true` in
   `ansible/group_vars/all.yml`, then:

```bash
cd /opt/homelab && sudo ./bootstrap.sh
```

```bash
sudo systemctl start homelab-duckdns.service && systemctl status homelab-duckdns.service --no-pager
```

A bad token puts the unit into `failed` rather than looping quietly, so a
green status here means the update really was accepted.

3. **Verify with the staging certificate.** Visit one of your DuckDNS names
   from outside your network. A certificate warning is the expected result —
   it proves the ACME challenge completed and the proxy is reachable.

4. **Switch to production.** Clear `CADDY_ACME_CA` in `config/secrets.env`,
   then re-render. The Caddyfile changes, so `render` reloads Caddy itself:

```bash
sudo /opt/homelab/scripts/render
```

## 10. Firewall

Last, because a wrong `lan_cidr` locks you out of SSH. Do this only once
Tailscale gives you a second way in.

Set both in `ansible/group_vars/all.yml`:

```yaml
firewall_enabled: true
firewall_public_web: true      # only if you completed phase 9
```

```bash
cd /opt/homelab && sudo ./bootstrap.sh
```

Keep a second SSH session open while you do this. If you do lock yourself out,
from a physical console:

```bash
nft delete table inet homelab
```

## 11. Backups

The nightly timer is already installed. Prove it works now, rather than
discovering it does not during a restore:

```bash
sudo systemctl start homelab-backup.service && cat /srv/backups/.last-status
```

For off-host replication, fill in `backup/restic.env` and initialise the
repository once. Until you do, snapshots exist only on this machine, which is
staging and not a backup:

```bash
sudo restic init
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| `render` dies on `MOSQUITTO_PASSWORD is empty` | Mosquitto is enabled but the password is unset. Set it, or disable mosquitto in `config/services.yml`. |
| `make validate` fails on a service you do not use | Every Compose file is checked. Fill that service's required variables even when it is disabled. |
| A service has no route and no warning | Its hostname in `config/domains.yml` is blank. A blank hostname is the supported way to keep it off the proxy. |
| `WARN: ... is not a service in config/services.yml` | An old-style key. Hostname keys are service directory names: `nextcloud-aio`, `uptime-kuma`, `stirling-pdf`. |
| Certificate errors on every public name | `CADDY_ACME_CA` is still pointed at staging. `render` warns about this on every run. |
| Public names time out | Ports 80/443 not forwarded, or `firewall_public_web` is false while `firewall_enabled` is true. |
| AdGuard will not bind :53 | `systemd-resolved` holds it. Set `DNSStubListener=no` in `/etc/systemd/resolved.conf` and restart it. |
| Backup unit shows `failed` | Read `/srv/backups/.last-status`; it lists each failed step. |
