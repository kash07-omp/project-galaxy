defmodule NexusDownfall.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :nexus_downfall,
    adapter: Ecto.Adapters.Postgres
end
