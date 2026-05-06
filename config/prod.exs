import Config

# Serve static files from priv/static in production
config :nexus_downfall, NexusDownfallWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

# Use Finch for HTTP requests in prod (Swoosh)
config :swoosh, :api_client, Swoosh.ApiClient.Finch, finch_name: NexusDownfall.Finch
