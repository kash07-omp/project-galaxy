import Config

# Test database — each CI worker gets its own DB via MIX_TEST_PARTITION
config :nexus_downfall, NexusDownfall.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "nexus_downfall_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Endpoint — no server needed during tests
config :nexus_downfall, NexusDownfallWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_local_secret_DO_NOT_USE_IN_PROD_replace_with_64_char_random_key",
  server: false

# Oban: inline mode — jobs execute synchronously on insert (no queues)
config :nexus_downfall, Oban, testing: :inline

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

# Disable Swoosh API client in tests
config :swoosh, :api_client, false

# Speed up auth-related tests (bcrypt defaults are intentionally expensive).
config :bcrypt_elixir, log_rounds: 4

# Redis — separate DB index for test isolation
config :nexus_downfall, :redis_url, "redis://localhost:6379/1"
