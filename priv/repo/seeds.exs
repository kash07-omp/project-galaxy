# priv/repo/seeds.exs
# Dev universe seed data.
#
# Run with: mix run priv/repo/seeds.exs
# Or as part of: mix ecto.setup

alias NexusDownfall.Repo
alias NexusDownfall.Universe.{UniverseRecord, Galaxy, SolarSystem}
alias NexusDownfall.Accounts.UniverseUser
alias NexusDownfall.Planets
alias NexusDownfall.Planets.{Planet, Building}
alias NexusDownfall.Accounts
import Ecto.Query

# ---------------------------------------------------------------------------
# Universe: Alpha (default dev universe)
# ---------------------------------------------------------------------------
alpha_attrs = %{name: "Alpha", slug: "alpha", status: "open", settings: %{}}

alpha =
  case Repo.get_by(UniverseRecord, slug: "alpha") do
    nil ->
      {:ok, universe} =
        %UniverseRecord{} |> UniverseRecord.creation_changeset(alpha_attrs) |> Repo.insert()

      IO.puts("[seeds] Created universe: #{universe.name} (#{universe.slug})")
      universe

    existing ->
      IO.puts("[seeds] Universe already exists: #{existing.name} (#{existing.slug})")
      existing
  end

# Create a seed galaxy + solar system so players can claim a planet on join
has_galaxy = Repo.exists?(from g in Galaxy, where: g.universe_id == ^alpha.id)

unless has_galaxy do
  {:ok, galaxy} =
    %Galaxy{} |> Galaxy.changeset(%{number: 1, universe_id: alpha.id}) |> Repo.insert()

  {:ok, _system} =
    %SolarSystem{}
    |> SolarSystem.changeset(%{number: 1, galaxy_id: galaxy.id, x: 0.0, y: 0.0})
    |> Repo.insert()

  IO.puts("[seeds] Created galaxy 1 + solar system 1 for universe #{alpha.name}")
end

# ---------------------------------------------------------------------------
# Dev test user (only in dev; never in prod)
# ---------------------------------------------------------------------------
unless System.get_env("MIX_ENV") == "prod" do
  dev_email = "dev@nexus.local"

  case Accounts.get_user_by_email(dev_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{email: dev_email, password: "dev-secret-password-42"})

      IO.puts("[seeds] Created dev user: #{user.email}")

    existing ->
      IO.puts("[seeds] Dev user already exists: #{existing.email}")
  end
end

IO.puts("[seeds] Done.")

# ---------------------------------------------------------------------------
# Dev planet: ensure starter buildings exist at level 1
# ---------------------------------------------------------------------------
# If the dev user already joined a universe before this seed runs,
# upgrade their existing planet's command_center + power_plant to level 1
# so production is immediately visible on first load.
unless System.get_env("MIX_ENV") == "prod" do
  dev_email = "dev@nexus.local"

  with dev_user when not is_nil(dev_user) <- Accounts.get_user_by_email(dev_email),
       universe_user when not is_nil(universe_user) <-
         Repo.get_by(UniverseUser, user_id: dev_user.id),
       planet when not is_nil(planet) <-
         Repo.one(from p in Planet, where: p.universe_user_id == ^universe_user.id, limit: 1) do
    {:ok, _} = Planets.ensure_building_slots(planet.id)

    {updated, _} =
      Repo.update_all(
        from(b in Building,
          where: b.planet_id == ^planet.id and b.type in ^["command_center", "power_plant"] and b.level < 1),
        set: [level: 1]
      )

    if updated > 0 do
      IO.puts("[seeds] Dev planet #{planet.name}: starter buildings set to level 1")
    end
  end
end
