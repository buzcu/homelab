#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ansible \
  git \
  python3 \
  python3-pip \
  python3-venv \
  python3-yaml

# Host-specific configuration. These files are gitignored.
seed() { # seed <example> <target> [mode]
  local example="$ROOT/$1" target="$ROOT/$2" mode="${3:-0644}"
  if [[ -f "$target" ]]; then
    return
  fi
  install -m "$mode" "$example" "$target"
  echo "Created $2 (from $1)"
}

seed ansible/inventory.yml.example        ansible/inventory.yml
seed ansible/group_vars/all.yml.example   ansible/group_vars/all.yml
seed config/domains.yml.example           config/domains.yml
seed config/secrets.env.example           config/secrets.env       0600
seed backup/restic.env.example            backup/restic.env        0600

chmod +x "$ROOT"/scripts/* 2>/dev/null || true
chmod 0600 "$ROOT/config/secrets.env" "$ROOT/backup/restic.env"

ansible-galaxy collection install -r "$ROOT/ansible/requirements.yml"

ansible-playbook \
  -i "$ROOT/ansible/inventory.yml" \
  "$ROOT/ansible/site.yml"

cat <<EOF

Host bootstrap complete.

Next:
  1. sudo tailscale up
  2. Fill in config/secrets.env   (every empty value is required)
     Generate values with: openssl rand -base64 36
  3. Review config/domains.yml, config/services.yml and config/versions.yml
  4. sudo $ROOT/scripts/render     (writes the Caddyfile and service configs)
  5. sudo make validate
  6. sudo $ROOT/scripts/deploy core

Nothing is exposed to the public Internet by this script.
EOF
