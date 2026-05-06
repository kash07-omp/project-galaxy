# priv/repo/seeds.exs
# Dev universe seed data.
#
# Run with: mix run priv/repo/seeds.exs
# Or as part of: mix ecto.setup
#
# Phase 0: Foundation only — no domain data yet.
# Phase 1 will seed: a default universe, a test user and initial planet.

alias NexusDownfall.Repo

IO.puts("""
[seeds] Phase 0 — Foundation.
  No domain seeds at this stage.
  Run `mix ecto.setup` to create the DB and apply migrations.
""")

_ = Repo
