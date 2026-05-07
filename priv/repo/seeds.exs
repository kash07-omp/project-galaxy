# priv/repo/seeds.exs
# Dev universe seed data.
#
# Run with: mix run priv/repo/seeds.exs
# Or as part of: mix ecto.setup
#
# Idempotent: safe to re-run. Existing rows are skipped via on_conflict: :nothing.

alias NexusDownfall.Repo
alias NexusDownfall.Universe.{UniverseRecord, Galaxy, SolarSystem, Hyperlink}
alias NexusDownfall.Accounts.UniverseUser
alias NexusDownfall.Planets
alias NexusDownfall.Planets.{Planet, Building}
alias NexusDownfall.Accounts
import Ecto.Query
alias NexusDownfall.Cards
alias NexusDownfall.Cards.Card
alias NexusDownfall.Fleets
alias NexusDownfall.Fleets.Fleet

# ---------------------------------------------------------------------------
# Universe: Alpha
# ---------------------------------------------------------------------------
alpha_attrs = %{name: "Alpha", slug: "alpha", status: "open", settings: %{}}

alpha =
  case Repo.get_by(UniverseRecord, slug: "alpha") do
    nil ->
      {:ok, universe} =
        %UniverseRecord{} |> UniverseRecord.creation_changeset(alpha_attrs) |> Repo.insert()

      IO.puts("[seeds] Created universe: #{universe.name}")
      universe

    existing ->
      IO.puts("[seeds] Universe exists: #{existing.name}")
      existing
  end

# ---------------------------------------------------------------------------
# Galaxy 1
# ---------------------------------------------------------------------------
galaxy =
  case Repo.get_by(Galaxy, universe_id: alpha.id, number: 1) do
    nil ->
      {:ok, g} =
        %Galaxy{} |> Galaxy.changeset(%{number: 1, universe_id: alpha.id}) |> Repo.insert()

      IO.puts("[seeds] Created galaxy 1")
      g

    g ->
      IO.puts("[seeds] Galaxy 1 exists")
      g
  end

# ---------------------------------------------------------------------------
# 12 solar systems: inner hexagon (1-7) + outer partial ring (8-12)
# ---------------------------------------------------------------------------
systems_config = [
  {1, 0.0, 0.0},
  {2, 200.0, 0.0},
  {3, 100.0, 173.0},
  {4, -100.0, 173.0},
  {5, -200.0, 0.0},
  {6, -100.0, -173.0},
  {7, 100.0, -173.0},
  {8, 400.0, 0.0},
  {9, 300.0, 260.0},
  {10, 0.0, 346.0},
  {11, -300.0, 260.0},
  {12, -400.0, 0.0}
]

systems =
  Enum.map(systems_config, fn {num, x, y} ->
    case Repo.get_by(SolarSystem, galaxy_id: galaxy.id, number: num) do
      nil ->
        {:ok, s} =
          %SolarSystem{}
          |> SolarSystem.changeset(%{number: num, galaxy_id: galaxy.id, x: x, y: y})
          |> Repo.insert()

        IO.puts("[seeds] Created system #{num}")
        s

      s ->
        s
    end
  end)

# ---------------------------------------------------------------------------
# Hyperlanes (hub-and-spoke inner ring + outer ring connections)
# Idempotent: on_conflict: :nothing on the unique index.
# ---------------------------------------------------------------------------
[s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12] = systems

hyperlink_pairs = [
  # Inner hub-and-spoke
  {s1, s2},
  {s1, s3},
  {s1, s4},
  {s1, s5},
  {s1, s6},
  {s1, s7},
  # Inner ring
  {s2, s3},
  {s3, s4},
  {s4, s5},
  {s5, s6},
  {s6, s7},
  {s7, s2},
  # Outer ring connects to nearest inner
  {s2, s8},
  {s3, s9},
  {s4, s10},
  {s5, s11},
  {s6, s12},
  # Outer ring partial connections
  {s8, s9},
  {s9, s10},
  {s10, s11},
  {s11, s12}
]

Enum.each(hyperlink_pairs, fn {a, b} ->
  {aid, bid} = if a.id < b.id, do: {a.id, b.id}, else: {b.id, a.id}

  %Hyperlink{}
  |> Hyperlink.changeset(%{system_a_id: aid, system_b_id: bid})
  |> Repo.insert(on_conflict: :nothing, conflict_target: [:system_a_id, :system_b_id])
end)

IO.puts("[seeds] Hyperlanes ensured (#{length(hyperlink_pairs)} pairs)")

# ---------------------------------------------------------------------------
# Planet slots per system (pre-seeded, unclaimed)
#
# Each orbit has exactly one slot: either a planet (with subtype) or an
# asteroid_ring. Subtypes cycle through a palette so adjacent systems differ.
#
# {system_number, orbit_count, asteroid_ring_orbits}
# ---------------------------------------------------------------------------
planet_subtypes = [
  "rocky",
  "lava",
  "rocky",
  "desert",
  "ocean",
  "ice",
  "rocky",
  "gas_giant",
  "ice",
  "rocky",
  "ocean",
  "lava",
  "desert",
  "gas_giant",
  "rocky"
]

system_slot_specs = [
  {1, 12, MapSet.new([5, 9])},
  {2, 10, MapSet.new([4, 8])},
  {3, 9, MapSet.new([3, 7])},
  {4, 8, MapSet.new([4, 7])},
  {5, 11, MapSet.new([2, 6, 9])},
  {6, 7, MapSet.new([3, 6])},
  {7, 13, MapSet.new([4, 8, 11])},
  {8, 9, MapSet.new([3, 7])},
  {9, 8, MapSet.new([4, 6])},
  {10, 7, MapSet.new([2, 5])},
  {11, 10, MapSet.new([3, 7, 9])},
  {12, 8, MapSet.new([4, 7])}
]

systems_by_number = Map.new(systems, fn s -> {s.number, s} end)

Enum.each(system_slot_specs, fn {sys_num, orbit_count, asteroid_orbits} ->
  system = systems_by_number[sys_num]
  # offset so each system has different starting subtype
  planet_idx_offset = (sys_num - 1) * 3

  Enum.each(1..orbit_count, fn orbit ->
    is_asteroid = MapSet.member?(asteroid_orbits, orbit)
    slot_type = if is_asteroid, do: "asteroid_ring", else: "planet"

    subtype =
      if is_asteroid,
        do: nil,
        else:
          Enum.at(planet_subtypes, rem(orbit - 1 + planet_idx_offset, length(planet_subtypes)))

    label = if is_asteroid, do: "Belt", else: "Planet"
    slot_name = "#{label} #{sys_num}-#{orbit}"

    %Planet{}
    |> Planet.initial_changeset(%{
      name: slot_name,
      orbit_position: orbit,
      region: 1,
      slot_type: slot_type,
      planet_subtype: subtype,
      universe_id: alpha.id,
      solar_system_id: system.id,
      last_tick_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:solar_system_id, :orbit_position, :region]
    )
  end)

  IO.puts("[seeds] System #{sys_num}: #{orbit_count} slots ensured")
end)

# ---------------------------------------------------------------------------
# Dev test user
# ---------------------------------------------------------------------------
unless System.get_env("MIX_ENV") == "prod" do
  dev_email = "dev@nexus.local"

  case Accounts.get_user_by_email(dev_email) do
    nil ->
      {:ok, user} =
        Accounts.register_user(%{email: dev_email, password: "dev-secret-password-42"})

      IO.puts("[seeds] Created dev user: #{user.email}")

    existing ->
      IO.puts("[seeds] Dev user exists: #{existing.email}")
  end
end

IO.puts("[seeds] Done.")

# ---------------------------------------------------------------------------
# Global card catalog
# ---------------------------------------------------------------------------
cards_catalog = [
  %{
    type: "admiral",
    slug: "queen",
    name: "Queen",
    description:
      "Ex-pirate captain renowned for lightning guerrilla tactics. Her instinctive reading of chaotic engagements grants all light fighters, heavy fighters and corvettes under her command a 5% evasion advantage.",
    image_path: "cards/admiral-0.jpg",
    rarity: "rare",
    bonuses: %{
      "effects" => [
        %{
          "type" => "stat_bonus",
          "stat" => "evasion",
          "ship_types" => ["light_fighter", "heavy_fighter", "corvette"],
          "modifier" => "percentage",
          "value" => 5
        }
      ]
    }
  }
]

Enum.each(cards_catalog, fn attrs ->
  case Repo.get_by(Card, slug: attrs.slug) do
    nil ->
      {:ok, card} = %Card{} |> Card.changeset(attrs) |> Repo.insert()
      IO.puts("[seeds] Created card: #{card.name} (#{card.slug})")

    existing ->
      IO.puts("[seeds] Card exists: #{existing.name} (#{existing.slug})")
  end
end)

# ---------------------------------------------------------------------------
# Give Queen card to dev user and assign to first fleet
# ---------------------------------------------------------------------------
unless System.get_env("MIX_ENV") == "prod" do
  dev_email = "dev@nexus.local"

  with dev_user when not is_nil(dev_user) <- Accounts.get_user_by_email(dev_email),
       universe_user when not is_nil(universe_user) <-
         Repo.get_by(UniverseUser, user_id: dev_user.id),
       queen_card when not is_nil(queen_card) <- Repo.get_by(Card, slug: "queen") do
    {:ok, _} = Cards.give_card_to_universe_user(universe_user.id, queen_card.id)
    IO.puts("[seeds] Gave Queen card to dev user #{dev_user.email}")

    first_fleet =
      Repo.one(from f in Fleet, where: f.universe_user_id == ^universe_user.id, limit: 1)

    fleet =
      if first_fleet do
        first_fleet
      else
        first_planet =
          Repo.one(from p in Planet, where: p.universe_user_id == ^universe_user.id, limit: 1)

        if first_planet do
          {:ok, created_fleet} =
            Fleets.create_fleet_for_user(dev_user.id, %{
              "name" => "Dev Fleet",
              "planet_id" => first_planet.id,
              "admiral_name" => ""
            })

          IO.puts("[seeds] Created dev fleet '#{created_fleet.name}'")
          created_fleet
        end
      end

    if fleet do
      {:ok, _} = Fleets.assign_admiral_to_fleet(fleet.id, dev_user.id, queen_card.id)
      IO.puts("[seeds] Assigned Queen to fleet '#{fleet.name}'")
    end
  else
    _ -> IO.puts("[seeds] Skipped Queen assignment (no dev user or fleet yet)")
  end
end

# ---------------------------------------------------------------------------
# Dev planet: ensure starter buildings at level 1
# ---------------------------------------------------------------------------
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
          where:
            b.planet_id == ^planet.id and b.type in ^["command_center", "power_plant"] and
              b.level < 1
        ),
        set: [level: 1]
      )

    if updated > 0, do: IO.puts("[seeds] Dev planet #{planet.name}: starter buildings -> level 1")
  end
end
