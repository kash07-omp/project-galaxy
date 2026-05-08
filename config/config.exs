import Config

config :nexus_downfall,
  ecto_repos: [NexusDownfall.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :nexus_downfall, NexusDownfallWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: NexusDownfallWeb.ErrorHTML, json: NexusDownfallWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NexusDownfall.PubSub,
  live_view: [signing_salt: "NexusLVSalt"]

# Configure mailer — local adapter for dev/test
config :nexus_downfall, NexusDownfall.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  nexus_downfall: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.4.3",
  nexus_downfall: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Oban — background job processing
# Queues:
#   :default   — general async tasks
#   :production — tick-based production jobs (Planet resource accumulation)
#   :combat     — combat resolution
config :nexus_downfall, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, construction: 10, production: 5, combat: 5, missions: 15],
  repo: NexusDownfall.Repo

import_config "#{config_env()}.exs"
