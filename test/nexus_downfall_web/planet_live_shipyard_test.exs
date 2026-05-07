defmodule NexusDownfallWeb.PlanetLiveShipyardTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts
  alias NexusDownfall.Fleets
  alias NexusDownfall.Fleets.FleetShip
  alias NexusDownfall.Fleets.ShipyardQueueItem
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.Building
  alias NexusDownfall.Planets.Planet
  alias NexusDownfall.Repo

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Test Universe",
        slug: "planet-live-#{System.unique_integer([:positive])}",
        status: "open"
      })
      |> Repo.insert()

    universe
  end

  defp create_galaxy(universe) do
    {:ok, galaxy} =
      %NexusDownfall.Universe.Galaxy{}
      |> NexusDownfall.Universe.Galaxy.changeset(%{number: 1, universe_id: universe.id})
      |> Repo.insert()

    galaxy
  end

  defp create_system(galaxy) do
    {:ok, system} =
      %NexusDownfall.Universe.SolarSystem{}
      |> NexusDownfall.Universe.SolarSystem.changeset(%{
        number: 1,
        galaxy_id: galaxy.id,
        x: 0.0,
        y: 0.0
      })
      |> Repo.insert()

    system
  end

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "planet-live-#{System.unique_integer([:positive])}@test.com",
        password: "supersecretpassword123"
      })

    user
  end

  defp create_universe_user(universe, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, universe_user} =
      %NexusDownfall.Accounts.UniverseUser{}
      |> NexusDownfall.Accounts.UniverseUser.join_changeset(%{
        universe_id: universe.id,
        user_id: user.id,
        username: "Commander#{System.unique_integer([:positive])}",
        joined_at: now
      })
      |> Repo.insert()

    universe_user
  end

  defp create_planet(system, universe_user, orbit_position, name) do
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

  defp force_spaceport_level_1(planet_id) do
    Repo.update_all(
      from(b in Building, where: b.planet_id == ^planet_id and b.type == "spaceport"),
      set: [level: 1]
    )
  end

  setup %{conn: conn} do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    universe_user = create_universe_user(universe, user)

    planet = create_planet(system, universe_user, 2, "Shipyard Home")
    _planet_2 = create_planet(system, universe_user, 3, "Shipyard Home 2")

    force_spaceport_level_1(planet.id)

    {:ok, fleet} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Alpha Fleet",
        "planet_id" => planet.id,
        "admiral_name" => ""
      })

    token = Accounts.generate_user_session_token(user)
    conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

    {:ok, conn: conn, user: user, universe_user: universe_user, planet: planet, fleet: fleet}
  end

  test "submit_build_order queues ships and shows success", %{conn: conn, planet: planet, fleet: fleet} do
    {:ok, lv, _html} = live(conn, ~p"/planets/#{planet.id}")

    render_click(lv, "select_building", %{"type" => "spaceport"})
    render_click(lv, "select_tab", %{"tab" => "specific"})
    render_click(lv, "grant_test_resources", %{})

    render_change(lv, "set_target_fleet", %{"fleet_id" => to_string(fleet.id)})
    render_submit(lv, "add_to_build_order", %{"ship_type" => "light_fighter", "quantity" => "2"})

    html = render_click(lv, "submit_build_order", %{})

    assert html =~ "Ships queued successfully!"

    queued =
      Repo.one!(
        from q in ShipyardQueueItem,
          where:
            q.planet_id == ^planet.id and q.fleet_id == ^fleet.id and q.ship_type == "light_fighter",
          order_by: [desc: q.inserted_at],
          limit: 1
      )

    assert queued.status in ["completed", "building", "queued"]

    fleet_ship =
      Repo.one!(
        from fs in FleetShip,
          where: fs.fleet_id == ^fleet.id and fs.ship_type == "light_fighter",
          limit: 1
      )

    assert fleet_ship.quantity == 2
  end

  test "grant_test_resources raises resource floor", %{conn: conn, planet: planet} do
    {:ok, lv, _html} = live(conn, ~p"/planets/#{planet.id}")

    render_click(lv, "select_building", %{"type" => "spaceport"})
    render_click(lv, "select_tab", %{"tab" => "specific"})

    html = render_click(lv, "grant_test_resources", %{})
    assert html =~ "Test resources added to this planet."

    updated = Repo.get!(Planet, planet.id)
    assert updated.raw_materials >= 50_000_000
    assert updated.microchips >= 50_000_000
    assert updated.hydrogen >= 50_000_000
    assert updated.food >= 50_000_000
    assert updated.credits >= 50_000_000
  end
end
