.PHONY: validate health

validate:
	@find services -name compose.yml -print0 | while IFS= read -r -d '' f; do \
	  echo "==> $$f"; docker compose -f "$$f" config -q; \
	done

health:
	@sudo ./scripts/healthcheck
