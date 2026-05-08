defmodule NexusDownfall.Fleets.AttackMissionTest do
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.UniverseUser
  alias NexusDownfall.Fleets
  alias NexusDownfall.Fleets.{Fleet, FleetMission, FleetShip}
  alias NexusDownfall.Notifications.Notification
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Defense, Defenses, Planet}
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, SolarSystem, UniverseRecord}

  defp create_universe do
    {:ok, universe} =
      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Attack Test Universe",
        slug: "attack-test-#{System.unique_integer([:positive])}",
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

  defp set_defenses(planet_id, defenses_map) do
    {:ok, _defenses} = Defenses.ensure_defense_slots(planet_id)

    Enum.each(defenses_map, fn {type, quantity} ->
      Repo.update_all(
        from(d in Defense, where: d.planet_id == ^planet_id and d.defense_type == ^type),
        set: [quantity: quantity]
      )
    end)
  end

  setup do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)

    attacker = create_user("attack-attacker")
    defender = create_user("attack-defender")
    attacker_uu = create_universe_user(universe, attacker)
    defender_uu = create_universe_user(universe, defender)

    home_planet = create_owned_planet(system, attacker_uu, 2, "Strike Alpha")
    target_planet = create_owned_planet(system, defender_uu, 5, "Shield Beta")

    home_planet =
      set_planet_resources(home_planet, %{
        raw_materials: 20_000,
        microchips: 10_000,
        hydrogen: 80_000,
        food: 8_000,
        credits: 6_000
      })

    set_defenses(target_planet.id, %{"missile_platform" => 2})

    {:ok, fleet} =
      Fleets.create_fleet_for_user(attacker.id, %{
        "name" => "Attack Fleet #{System.unique_integer([:positive])}",
        "planet_id" => home_planet.id
      })

    set_fleet_ships(fleet.id, %{"corvette" => 20})

    %{attacker: attacker, defender: defender, home_planet: home_planet, target_planet: target_planet, fleet: fleet}
  end

  test "dispatches attack and resolves planetary defenses on arrival", %{
    attacker: attacker,
    defender: defender,
    home_planet: home_planet,
    target_planet: target_planet,
    fleet: fleet
  } do
    before_hydrogen = home_planet.hydrogen

    {:ok, mission} =
      Oban.Testing.with_testing_mode(:manual, fn ->
        Fleets.dispatch_attack_mission_for_user(fleet.id, attacker.id, target_planet.id)
      end)

    assert mission.mission_type == "attack"
    assert mission.phase == "outbound"
    assert mission.hydrogen_cost > 0
    assert Repo.get!(Planet, home_planet.id).hydrogen == before_hydrogen - mission.hydrogen_cost

    assert_enqueued(
      worker: NexusDownfall.Workers.FleetMissionWorker,
      args: %{"mission_id" => mission.id, "action" => "arrive"}
    )

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok == Fleets.process_mission_transition(mission.id, "arrive")
    end)

    mission = Repo.get!(FleetMission, mission.id)
    assert mission.phase == "returning"
    assert mission.result_reason == "attack_victory"
    assert Repo.get!(Fleet, fleet.id).status == "returning"

    assert Repo.get_by!(Defense, planet_id: target_planet.id, defense_type: "missile_platform").quantity ==
             0

    assert Repo.get_by!(FleetShip, fleet_id: fleet.id, ship_type: "corvette").quantity >= 0

    attacker_notification =
      Repo.one!(
        from n in Notification,
          where: n.user_id == ^attacker.id and n.type == "battle_report",
          order_by: [desc: n.id],
          limit: 1
      )

    defender_notification =
      Repo.one!(
        from n in Notification,
          where: n.user_id == ^defender.id and n.type == "battle_report",
          order_by: [desc: n.id],
          limit: 1
      )

    assert attacker_notification.payload["recipient_role"] == "attacker"
    assert defender_notification.payload["recipient_role"] == "defender"

    assert attacker_notification.payload["mission_id"] == mission.id
    assert defender_notification.payload["mission_id"] == mission.id

    assert is_list(attacker_notification.payload["attacker_losses"])
    assert is_list(attacker_notification.payload["defender_losses"])

    assert is_map(attacker_notification.payload["attacker_total_cost"])
    assert is_map(attacker_notification.payload["defender_total_cost"])

    assert attacker_notification.payload["looted_resources"] == %{
             "raw_materials" => 0,
             "microchips" => 0,
             "hydrogen" => 0
           }
  end

  test "rejects attacks against own or empty planets", %{
    attacker: attacker,
    home_planet: home_planet,
    target_planet: target_planet,
    fleet: fleet
  } do
    assert {:error, :invalid_target} =
             Fleets.dispatch_attack_mission_for_user(fleet.id, attacker.id, home_planet.id)

    Repo.update_all(
      from(p in Planet, where: p.id == ^target_planet.id),
      set: [universe_user_id: nil]
    )

    assert {:error, :target_unavailable} =
             Fleets.dispatch_attack_mission_for_user(fleet.id, attacker.id, target_planet.id)
  end
end
