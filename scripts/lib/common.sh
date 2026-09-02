# Shared helpers. Source this; do not execute it.
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

# Where scripts/render writes the merged Compose environment. /run is tmpfs,
# so secrets never touch the disk and never sit inside the Git working tree.
# Overridable so CI can validate without root.
COMPOSE_ENV="${COMPOSE_ENV:-/run/homelab/compose.env}"
RUNTIME_DIR="$(dirname "$COMPOSE_ENV")"
export RUNTIME_DIR COMPOSE_ENV

# Shared Docker network for containers that must talk to each other
# (Mosquitto <-> Zigbee2MQTT, LDAP consumers <-> LLDAP).
HOMELAB_NETWORK="homelab"
export HOMELAB_NETWORK

DEPLOY_GROUPS_ORDER=(core documents photos media books business)
declare -A DEPLOY_GROUPS=(
  [core]="caddy nextcloud-aio vaultwarden homeassistant mosquitto zigbee2mqtt lldap adguard uptime-kuma"
  [documents]="paperless stirling-pdf"
  [photos]="immich"
  [media]="jellyfin qbittorrent prowlarr radarr sonarr"
  [books]="calibre"
  [business]="odoo forgejo"
)
export DEPLOY_GROUPS_ORDER

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "must run as root: sudo $0 $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# python3 + PyYAML parse the repository's YAML. Installed by bootstrap.sh and
# by the Ansible base role (Debian package python3-yaml).
require_yaml() {
  require_cmd python3
  python3 -c 'import yaml' 2>/dev/null \
    || die "PyYAML missing. Install it: apt-get install -y python3-yaml"
}

# Ensure scripts/render has produced the Compose environment.
require_compose_env() {
  [[ -r "$COMPOSE_ENV" ]] \
    || die "$COMPOSE_ENV missing. Run: sudo $ROOT/scripts/render"
}

# docker compose, always with the rendered environment.
dc() {
  docker compose --env-file "$COMPOSE_ENV" "$@"
}

# Expand a category name to its services, or pass a single service through.
resolve_target() {
  local target="$1"
  if [[ "$target" == "all" ]]; then
    local g
    for g in "${DEPLOY_GROUPS_ORDER[@]}"; do
      printf '%s\n' ${DEPLOY_GROUPS[$g]}
    done
  elif [[ -n "${DEPLOY_GROUPS[$target]:-}" ]]; then
    printf '%s\n' ${DEPLOY_GROUPS[$target]}
  else
    printf '%s\n' "$target"
  fi
}

# Read config/services.yml and echo "true"/"false" for a service.
# An unlisted service defaults to enabled so a new Compose directory is never
# silently skipped.
service_enabled() {
  local svc="$1"
  local file="$ROOT/config/services.yml"
  [[ -f "$file" ]] || { echo true; return; }
  python3 - "$file" "$svc" <<'PY'
import sys, yaml
path, svc = sys.argv[1], sys.argv[2]
with open(path) as fh:
    data = yaml.safe_load(fh) or {}
for group in data.values():
    if isinstance(group, dict) and svc in group:
        print("true" if group[svc] else "false")
        sys.exit(0)
print("true")
PY
}
