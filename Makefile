.PHONY: validate versions compose-validate lint health render help

help:
	@echo "make validate  Check image pins, then validate every Compose file"
	@echo "make versions  Check config/versions.yml against services/*/compose.yml"
	@echo "make lint      shellcheck + yamllint (if installed)"
	@echo "make render    Regenerate the Compose env, Caddyfile and service configs"
	@echo "make health    Run scripts/healthcheck"

validate: versions compose-validate

versions:
	@./scripts/check-versions

# Every Compose file is checked and the failures are collected, so an invalid
# file early in the list cannot be masked by a valid one later.
compose-validate:
	@set -u; rc=0; \
	for f in services/*/compose.yml; do \
	  printf '==> %s\n' "$$f"; \
	  docker compose --env-file /run/homelab/compose.env -f "$$f" config -q || rc=1; \
	done; \
	if [ "$$rc" -ne 0 ]; then echo "Compose validation FAILED" >&2; fi; \
	exit $$rc

lint:
	@set -u; rc=0; \
	if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -x bootstrap.sh scripts/render scripts/deploy scripts/backup \
	    scripts/healthcheck scripts/update-images scripts/check-versions \
	    scripts/duckdns-update scripts/lib/common.sh || rc=1; \
	else echo "shellcheck not installed; skipping"; fi; \
	if command -v yamllint >/dev/null 2>&1; then \
	  yamllint . || rc=1; \
	else echo "yamllint not installed; skipping"; fi; \
	exit $$rc

render:
	@sudo ./scripts/render

health:
	@sudo ./scripts/healthcheck
