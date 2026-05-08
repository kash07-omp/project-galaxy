defmodule NexusDownfall.Fleets.ColonizationMissionTest do
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.UniverseUser
  alias NexusDownfall.Fleets
  alias NexusDownfall.Fleets.{FleetMission, FleetShip}
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.Planet
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, SolarSystem, UniverseRecord}

  defp create_universe do
    {:ok, universe} =
      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Colonization Test Universe",
        slug: "colonization-test-#{System.unique_integer([:positive])}",
        status: "open"
      })
      |> Repo.insert()

    universe
  end

  defp create_galaxy(universe) do
    {:ok, galaxy} =
      %Galaxy{}
      |> Galaxy.changeset(%{number: 1, universe_id: universe.id})
      |> Repo.insert()

    galaxy
  end

  defp create_system(galaxy, number, x) do
    {:ok, system} =
      %SolarSystem{}
      |> SolarSystem.changeset(%{number: number, galaxy_id: galaxy.id, x: x, y: 0.0})
      |> Repo.insert()

    system
  end

  defp create_user(email_prefix) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "#{email_prefix}-#{System.unique_integer([:positive])}@test.com",
        password: "supersecretpassword123"
      })

    user
  end

  defp create_universe_user(universe, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, universe_user} =
      %UniverseUser{}
      |> UniverseUser.join_changeset(%{
        universe_id: universe.id,
        user_id: user.id,
        username: "Commander#{System.unique_integer([:positive])}",
        joined_at: now
      })
      |> Repo.insert()

    universe_user
  end

  defp create_owned_planet(system, universe_user, orbit_position, name) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: name,
        orbit_position: orbit_position,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    planet
  end

  defp create_free_planet(system, orbit_position, region \\ 1) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, planet} =
      %Planet{}
      |> Planet.initial_changeset(%{
        name: "Unclaimed #{System.unique_integer([:positive])}",
        orbit_position: orbit_position,
        region: region,
        slot_type: "planet",
        universe_id: system.galaxy.universe_id,
        solar_system_id: system.id,
        last_tick_at: now
      })
      |> Repo.insert()

    planet
  end

  defp set_fleet_ships(fleet_id, ships_map) do
    Enum.each(ships_map, fn {type, quantity} ->
      Repo.update_all(
        from(fs in FleetShip, where: fs.fleet_id == ^fleet_id and fs.ship_type == ^type),
        set: [quantity: quantity]
      )
    end)
  end

  setup do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system_a = create_system(galaxy, 1, 0.0)
    system_b = create_system(galaxy, 2, 100.0)

    # Preload galaxy for helper that needs universe_id from nested struct.
    system_a = Repo.preload(system_a, :galaxy)
    system_b = Repo.preload(system_b, :galaxy)

    {:ok, _link} = NexusDownfall.Universe.create_hyperlink(system_a.id, system_b.id)

    user = create_user("colonization")
    universe_user = create_universe_user(universe, user)

    home_planet = create_owned_planet(system_a, universe_user, 2, "Home Alpha")

    Repo.update_all(from(p in Planet, where: p.id == ^home_planet.id), set: [hydrogen: 5_000_000])

    {:ok, fleet} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Colony Fleet #{System.unique_integer([:positive])}",
        "planet_id" => home_planet.id
      })

    %{universe: universe, system_a: system_a, system_b: system_b, user: user, home_planet: home_planet, fleet: fleet}
  end

  test "dispatches colonization mission, stores timings and consumes hydrogen", %{fleet: fleet, home_planet: home_planet, system_b: system_b, user: user} do
    target_planet = create_free_planet(system_b, 5)
    set_fleet_ships(fleet.id, %{"colonizer" => 1})

    before_hydrogen = Repo.get!(Planet, home_planet.id).hydrogen

    {:ok, mission} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        Fleets.dispatch_colonization_mission_for_user(fleet.id, user.id, target_planet.id)
      end)

    assert mission.phase == "outbound"
    assert mission.mission_type == "colonization"
    assert mission.outbound_travel_seconds > 0
    assert mission.colonization_seconds > 0
    assert mission.return_travel_seconds > 0
    assert mission.hydrogen_cost > 0
    assert mission.current_oban_job_id

    after_hydrogen = Repo.get!(Planet, home_planet.id).hydrogen
    assert after_hydrogen < before_hydrogen

    updated_fleet = Repo.get!(NexusDownfall.Fleets.Fleet, fleet.id)
    assert updated_fleet.status == "outbound"
  end

  test "only first arrival starts colonization and late mission returns", %{universe: universe, system_a: system_a, system_b: system_b, user: user, home_planet: home_planet} do
    target_planet = create_free_planet(system_b, 6)

    user2 = create_user("colonization-rival")
    universe_user2 = create_universe_user(universe, user2)
    home_2 = create_owned_planet(system_a, universe_user2, 3, "Home Beta")

    Repo.update_all(from(p in Planet, where: p.id in [^home_2.id]), set: [hydrogen: 5_000_000])

    {:ok, fleet_a} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Fleet A #{System.unique_integer([:positive])}",
        "planet_id" => home_planet.id
      })

    {:ok, fleet_b} =
      Fleets.create_fleet_for_user(user2.id, %{
        "name" => "Fleet B #{System.unique_integer([:positive])}",
        "planet_id" => home_2.id
      })

    set_fleet_ships(fleet_a.id, %{"colonizer" => 1})
    set_fleet_ships(fleet_b.id, %{"colonizer" => 1})

    {mission_a, mission_b} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, mission_a} = Fleets.dispatch_colonization_mission_for_user(fleet_a.id, user.id, target_planet.id)
        {:ok, mission_b} = Fleets.dispatch_colonization_mission_for_user(fleet_b.id, user2.id, target_planet.id)
        {mission_a, mission_b}
      end)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok == Fleets.process_mission_transition(mission_a.id, "arrive")
      assert :ok == Fleets.process_mission_transition(mission_b.id, "arrive")
    end)

    mission_a = Repo.get!(FleetMission, mission_a.id)
    mission_b = Repo.get!(FleetMission, mission_b.id)

    assert mission_a.phase == "colonizing"
    assert mission_b.phase == "returning"
    assert mission_b.result_reason == "late_arrival"
  end

  test "successful colonization claims planet, consumes colonizer and returns escorts", %{fleet: fleet, system_b: system_b, user: user} do
    target_planet = create_free_planet(system_b, 7)

    set_fleet_ships(fleet.id, %{"colonizer" => 1, "light_fighter" => 3})

    {:ok, mission} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        Fleets.dispatch_colonization_mission_for_user(fleet.id, user.id, target_planet.id)
      end)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok == Fleets.process_mission_transition(mission.id, "arrive")
      assert :ok == Fleets.process_mission_transition(mission.id, "complete_colonization")
    end)

    target_planet = Repo.get!(Planet, target_planet.id)
    assert target_planet.universe_user_id == Repo.get!(NexusDownfall.Fleets.Fleet, fleet.id).universe_user_id

    colonizer_quantity =
      Repo.one!(
        from fs in FleetShip,
          where: fs.fleet_id == ^fleet.id and fs.ship_type == "colonizer",
          select: fs.quantity
      )

    assert colonizer_quantity == 0

    mission = Repo.get!(FleetMission, mission.id)

    assert mission.phase == "returning"
    assert :ok == Fleets.process_mission_transition(mission.id, "return")

    mission = Repo.get!(FleetMission, mission.id)
    assert mission.phase == "completed"

    updated_fleet = Repo.get!(NexusDownfall.Fleets.Fleet, fleet.id)
    assert updated_fleet.status == "idle"
  end
end
