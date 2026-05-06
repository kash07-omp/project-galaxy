import Config

# Configure your database
config :nexus_downfall, NexusDownfall.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "nexus_downfall_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, disable caching and enable debugging/code reloading.
config :nexus_downfall, NexusDownfallWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  # IMPORTANT: Replace in prod with `mix phx.gen.secret`
  secret_key_base: "dev_local_secret_DO_NOT_USE_IN_PROD_replace_with_64_char_random_key",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:nexus_downfall, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:nexus_downfall, ~w(--watch)]}
  ]

# Live reload patterns
config :nexus_downfall, NexusDownfallWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/nexus_downfall_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes (live_dashboard, etc.)
config :nexus_downfall, dev_routes: true

config :nexus_downfall, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Redis connection URL for dev
config :nexus_downfall, :redis_url, "redis://localhost:6379"
