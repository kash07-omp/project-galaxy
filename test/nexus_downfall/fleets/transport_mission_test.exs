defmodule NexusDownfall.Fleets.TransportMissionTest do
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.UniverseUser
  alias NexusDownfall.Fleets
  alias NexusDownfall.Fleets.{Fleet, FleetMission, FleetShip}
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.Planet
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, SolarSystem, UniverseRecord}

  defp create_universe do
    {:ok, universe} =
      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Transport Test Universe",
        slug: "transport-test-#{System.unique_integer([:positive])}",
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

  defp create_system(galaxy) do
    {:ok, system} =
      %SolarSystem{}
      |> SolarSystem.changeset(%{number: 1, galaxy_id: galaxy.id, x: 0.0, y: 0.0})
      |> Repo.insert()

    Repo.preload(system, :galaxy)
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

  defp set_planet_resources(planet, attrs) do
    Repo.update_all(
      from(p in Planet, where: p.id == ^planet.id),
      set: Enum.into(attrs, [])
    )

    Repo.get!(Planet, planet.id)
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
    system = create_system(galaxy)

    user = create_user("transport")
    universe_user = create_universe_user(universe, user)

    home_planet = create_owned_planet(system, universe_user, 2, "Logistics Alpha")
    target_planet = create_owned_planet(system, universe_user, 5, "Logistics Beta")

    home_planet =
      set_planet_resources(home_planet, %{
        raw_materials: 20_000,
        microchips: 10_000,
        hydrogen: 50_000,
        food: 8_000,
        credits: 6_000
      })

    target_planet =
      set_planet_resources(target_planet, %{
        raw_materials: 1_000,
        microchips: 1_000,
        hydrogen: 1_000,
        food: 1_000,
        credits: 1_000
      })

    {:ok, fleet} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Transport Fleet #{System.unique_integer([:positive])}",
        "planet_id" => home_planet.id
      })

    set_fleet_ships(fleet.id, %{"light_freighter" => 1})

    %{user: user, home_planet: home_planet, target_planet: target_planet, fleet: fleet}
  end

  test "dispatch consumes round-trip hydrogen using fleet fuel per second", %{
    fleet: fleet,
    home_planet: home_planet,
    target_planet: target_planet,
    user: user
  } do
    before_hydrogen = home_planet.hydrogen

    {:ok, mission} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        Fleets.dispatch_transport_mission_for_user(fleet.id, user.id, target_planet.id, %{
          "raw_materials" => "1000",
          "hydrogen" => "100"
        })
      end)

    assert mission.mission_type == "transport"
    assert mission.phase == "outbound"
    assert mission.cargo_raw_materials == 1000
    assert mission.cargo_hydrogen == 100

    expected_hydrogen_cost =
      Float.ceil(0.8 * (mission.outbound_travel_seconds + mission.return_travel_seconds))
      |> trunc()

    assert mission.hydrogen_cost == expected_hydrogen_cost

    after_home = Repo.get!(Planet, home_planet.id)
    assert after_home.raw_materials == home_planet.raw_materials - 1000
    assert after_home.hydrogen == before_hydrogen - expected_hydrogen_cost - 100

    assert Repo.get!(Fleet, fleet.id).status == "outbound"
  end

  test "arrival delivers cargo once, schedules return and return completes fleet", %{
    fleet: fleet,
    target_planet: target_planet,
    user: user
  } do
    before_target = Repo.get!(Planet, target_planet.id)

    {:ok, mission} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        Fleets.dispatch_transport_mission_for_user(fleet.id, user.id, target_planet.id, %{
          "raw_materials" => "1200",
          "microchips" => "300",
          "food" => "250",
          "credits" => "125"
        })
      end)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok == Fleets.process_mission_transition(mission.id, "arrive")
    end)

    delivered_target = Repo.get!(Planet, target_planet.id)
    assert delivered_target.raw_materials == before_target.raw_materials + 1200
    assert delivered_target.microchips == before_target.microchips + 300
    assert delivered_target.food == before_target.food + 250
    assert delivered_target.credits == before_target.credits + 125

    mission = Repo.get!(FleetMission, mission.id)
    assert mission.phase == "returning"
    assert mission.result_reason == "transport_delivered"
    assert mission.return_arrival_at
    assert Repo.get!(Fleet, fleet.id).status == "returning"

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok == Fleets.process_mission_transition(mission.id, "return")
    end)

    assert Repo.get!(FleetMission, mission.id).phase == "completed"
    assert Repo.get!(Fleet, fleet.id).status == "idle"
  end

  test "rejects cargo above fleet capacity or unavailable resources", %{
    fleet: fleet,
    home_planet: home_planet,
    target_planet: target_planet,
    user: user
  } do
    assert {:error, :cargo_exceeds_capacity} =
             Fleets.dispatch_transport_mission_for_user(fleet.id, user.id, target_planet.id, %{
               "raw_materials" => "5001"
             })

    Repo.update_all(
      from(p in Planet, where: p.id == ^home_planet.id),
      set: [credits: 3_000]
    )

    assert {:error, :insufficient_resources} =
             Fleets.dispatch_transport_mission_for_user(fleet.id, user.id, target_planet.id, %{
               "credits" => "4000"
             })
  end
end
