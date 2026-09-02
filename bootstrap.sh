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
  python3-venv

if [[ ! -f "$ROOT/ansible/inventory.yml" ]]; then
  cp "$ROOT/ansible/inventory.yml.example" "$ROOT/ansible/inventory.yml"
  echo "Created ansible/inventory.yml"
fi

if [[ ! -f "$ROOT/ansible/group_vars/all.yml" ]]; then
  cp "$ROOT/ansible/group_vars/all.yml.example" "$ROOT/ansible/group_vars/all.yml"
  echo "Created ansible/group_vars/all.yml"
fi

if [[ ! -f "$ROOT/config/domains.yml" ]]; then
  cp "$ROOT/config/domains.yml.example" "$ROOT/config/domains.yml"
  echo "Created config/domains.yml"
fi

ansible-galaxy collection install community.general

ansible-playbook \
  -i "$ROOT/ansible/inventory.yml" \
  "$ROOT/ansible/site.yml"

echo
echo "Host bootstrap complete."
echo "Next:"
echo "  1. Run: sudo tailscale up"
echo "  2. Review config/services.yml and config/versions.yml"
echo "  3. Run: sudo $ROOT/scripts/deploy core"
