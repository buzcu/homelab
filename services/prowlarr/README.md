# prowlarr

Keep indexer management private. Configure only lawful sources.

Prowlarr mounts its own config directory and nothing else: it manages indexers
and talks to Radarr/Sonarr over HTTP, so it never needs access to media,
downloads or any other service's data.
