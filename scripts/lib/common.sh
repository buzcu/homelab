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

SERVICES_FILE="$ROOT/config/services.yml"
export SERVICES_FILE

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "must run as root. Re-run with: sudo $0 ..."
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

# ---------------------------------------------------------------------------
# config/services.yml
# ---------------------------------------------------------------------------
# Parsed once per script run, not once per lookup. The catalogue is the single
# structural source: categories, enablement, Caddy upstreams and backup scope
# all come from here, so none of them can drift apart.
# Upstreams are not kept here: scripts/render reads them straight out of the
# catalogue when it builds the Caddyfile, and nothing in shell needs them.
declare -A SERVICE_CATEGORY SERVICE_ENABLED SERVICE_BACKUP
declare -A _CATEGORY_SEEN
declare -a SERVICE_ORDER CATEGORY_ORDER
_SERVICES_LOADED=false

# Loaded lazily so a script that never asks about services (healthcheck) still
# runs on a host without PyYAML.
_load_services() {
  [[ "$_SERVICES_LOADED" == true ]] && return 0
  [[ -f "$SERVICES_FILE" ]] || die "$SERVICES_FILE missing"
  require_yaml

  # Unit separator, not tab: tab is IFS whitespace, so consecutive tabs would
  # collapse and an empty field would silently shift every field after it.
  local name category enabled backup
  while IFS=$'\037' read -r name category enabled backup; do
    [[ -n "$name" ]] || continue
    SERVICE_ORDER+=("$name")
    SERVICE_CATEGORY["$name"]="$category"
    SERVICE_ENABLED["$name"]="$enabled"
    SERVICE_BACKUP["$name"]="$backup"
    if [[ -z "${_CATEGORY_SEEN[$category]:-}" ]]; then
      _CATEGORY_SEEN["$category"]=1
      CATEGORY_ORDER+=("$category")
    fi
  done < <(python3 - "$SERVICES_FILE" <<'PY'
import sys, yaml
# Never translate newlines: a \r would end up inside the last field.
sys.stdout.reconfigure(newline="\n")
with open(sys.argv[1]) as fh:
    doc = yaml.safe_load(fh) or {}
for name, spec in (doc.get("services") or {}).items():
    spec = spec or {}
    print("\x1f".join([
        name,
        str(spec.get("category", "")),
        "true" if spec.get("enabled", True) else "false",
        "true" if spec.get("backup", True) else "false",
    ]))
PY
  )

  [[ ${#SERVICE_ORDER[@]} -gt 0 ]] || die "$SERVICES_FILE defines no services"
  _SERVICES_LOADED=true
}

# "true"/"false" for a service. An unlisted service defaults to enabled so a
# new Compose directory is never silently skipped.
service_enabled() {
  _load_services
  echo "${SERVICE_ENABLED[$1]:-true}"
}

is_category() {
  _load_services
  [[ -n "${_CATEGORY_SEEN[$1]:-}" ]]
}

services_in_category() {
  _load_services
  local svc
  for svc in "${SERVICE_ORDER[@]}"; do
    [[ "${SERVICE_CATEGORY[$svc]}" == "$1" ]] && printf '%s\n' "$svc"
  done
  return 0
}

# Services whose /srv/data directory scripts/backup archives.
backed_up_services() {
  _load_services
  local svc
  for svc in "${SERVICE_ORDER[@]}"; do
    [[ "${SERVICE_BACKUP[$svc]}" == "true" ]] && printf '%s\n' "$svc"
  done
  return 0
}

# Expand a category name to its services, or pass a single service through.
resolve_target() {
  _load_services
  local target="$1"
  if [[ "$target" == "all" ]]; then
    printf '%s\n' "${SERVICE_ORDER[@]}"
  elif is_category "$target"; then
    services_in_category "$target"
  else
    printf '%s\n' "$target"
  fi
}

# "  core       caddy, nextcloud-aio, ..." for --help output.
describe_categories() {
  _load_services
  local category
  for category in "${CATEGORY_ORDER[@]}"; do
    local svcs
    # paste cycles through -d's characters, so a two-character list would
    # alternate ", " between items. Join with commas, then space them.
    svcs="$(services_in_category "$category" | paste -sd, - | sed 's/,/, /g')"
    printf '  %-10s %s\n' "$category" "$svcs"
  done
}
