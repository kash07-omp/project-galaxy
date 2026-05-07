defmodule NexusDownfallWeb.FleetLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts
  alias NexusDownfall.Fleets
  alias NexusDownfall.Fleets.Fleet
  alias NexusDownfall.Planets
  alias NexusDownfall.Repo

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Test Universe",
        slug: "fleet-live-#{System.unique_integer([:positive])}",
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
        email: "fleet-live-#{System.unique_integer([:positive])}@test.com",
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

  defp create_planet(system, universe_user) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: "Fleet Home",
        orbit_position: 2,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    planet
  end

  setup %{conn: conn} do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    universe_user = create_universe_user(universe, user)
    planet = create_planet(system, universe_user)

    token = Accounts.generate_user_session_token(user)
    conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

    {:ok, conn: conn, user: user, universe_user: universe_user, planet: planet}
  end

  test "create fleet button opens modal and creates fleet", %{conn: conn, planet: planet, universe_user: universe_user} do
    fleet_name = "Fleet #{System.unique_integer([:positive])}"

    {:ok, live_view, html} = live(conn, ~p"/fleet")
    assert html =~ "Fleet Management"

    live_view
    |> element("button[phx-click='open_create_fleet_modal']", "New Fleet")
    |> render_click()

    assert render(live_view) =~ "Create fleet"

    live_view
    |> form("form[phx-submit='create_fleet']", %{
      "name" => fleet_name,
      "planet_id" => to_string(planet.id)
    })
    |> render_submit()

    rendered = render(live_view)
    assert rendered =~ "Fleet created successfully."
    assert rendered =~ fleet_name

    fleet = Repo.get_by!(Fleet, name: fleet_name, universe_user_id: universe_user.id)

    # Ensure the initialized ship slots exist so the roster can render quantities immediately.
    assert Repo.exists?(from fs in NexusDownfall.Fleets.FleetShip, where: fs.fleet_id == ^fleet.id)
  end

  test "fleet live refreshes on ship-built pubsub event", %{conn: conn, user: user, planet: planet} do
    {:ok, fleet} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Realtime Fleet",
        "planet_id" => planet.id,
        "admiral_name" => ""
      })

    {:ok, live_view, html} = live(conn, ~p"/fleet")
    assert html =~ "Realtime Fleet"
    assert html =~ ">0<"

    # Simulate the persisted state that FleetLive reloads after receiving the event.
    Repo.update_all(
      from(fs in NexusDownfall.Fleets.FleetShip,
        where: fs.fleet_id == ^fleet.id and fs.ship_type == "light_fighter"
      ),
      set: [quantity: 1]
    )

    Phoenix.PubSub.broadcast(
      NexusDownfall.PubSub,
      Fleets.fleet_updates_topic_for_user(user.id),
      {:fleet_ship_built,
       %{fleet_id: fleet.id, ship_type: "light_fighter", fleet_ship_quantity: 1, planet_id: planet.id}}
    )

    refreshed = render(live_view)
    assert refreshed =~ "Realtime Fleet"
    assert refreshed =~ ">1<"
  end
end
