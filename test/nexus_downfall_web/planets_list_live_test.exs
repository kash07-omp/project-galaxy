defmodule NexusDownfallWeb.PlanetsListLiveTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts
  alias NexusDownfall.Fleets
  alias NexusDownfall.Planets
  alias NexusDownfall.Repo

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Planets Test Universe",
        slug: "planets-list-#{System.unique_integer([:positive])}",
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
        email: "planets-list-#{System.unique_integer([:positive])}@test.com",
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

  setup %{conn: conn} do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    universe_user = create_universe_user(universe, user)

    planet_a = create_planet(system, universe_user, 2, "Aster Prime")
    planet_b = create_planet(system, universe_user, 5, "Nereid")

    token = Accounts.generate_user_session_token(user)
    conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

    {:ok, fleet} =
      Fleets.create_fleet_for_user(user.id, %{
        "name" => "Premium Fleet",
        "planet_id" => planet_a.id,
        "admiral_name" => ""
      })

    {:ok, conn: conn, user: user, planet_a: planet_a, planet_b: planet_b, fleet: fleet}
  end

  test "renders the player's planets with coordinates and stable image paths", %{
    conn: conn,
    planet_a: planet_a,
    planet_b: planet_b
  } do
    {:ok, _lv, html} = live(conn, ~p"/planets")

    assert html =~ "Planetary Management"
    assert html =~ "Aster Prime"
    assert html =~ "Nereid"
    assert html =~ "[1:1:2:1]"
    assert html =~ "[1:1:5:1]"
    assert html =~ "/images/Planets/#{planet_a.planet_image_id}.png"
    assert html =~ "/images/Planets/#{planet_b.planet_image_id}.png"
  end

  test "keeps premium-only filters hidden for standard users", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/planets")

    refute html =~ "Advanced Filters"
    refute html =~ "Sort By"
    refute html =~ "Total Resources"
  end

  test "shows premium-only filters and extra data for premium users", %{
    conn: conn,
    user: user,
    planet_a: planet_a
  } do
    {:ok, _user} = user |> Ecto.Changeset.change(premium: true) |> Repo.update()

    token = Accounts.generate_user_session_token(user)
    premium_conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

    {:ok, _lv, html} = live(premium_conn, ~p"/planets")

    assert html =~ "Advanced Filters"
    assert html =~ "Sort By"
    assert html =~ "Total Resources"
    assert html =~ "fleets stationed"
    assert html =~ "/images/Planets/#{planet_a.planet_image_id}.png"
  end
end
