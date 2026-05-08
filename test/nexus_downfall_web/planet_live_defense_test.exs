defmodule NexusDownfallWeb.PlanetLiveDefenseTest do
  use NexusDownfallWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias NexusDownfall.Accounts
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Defense}
  alias NexusDownfall.Repo

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Defense Live Universe",
        slug: "defense-live-#{System.unique_integer([:positive])}",
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
        email: "planet-defense-#{System.unique_integer([:positive])}@test.com",
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
        username: "LiveDefender#{System.unique_integer([:positive])}",
        joined_at: now
      })
      |> Repo.insert()

    universe_user
  end

  defp create_planet(system, universe_user) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: "Defense Live Home",
        orbit_position: 2,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    planet
  end

  defp force_defense_center_level_1(planet_id) do
    Repo.update_all(
      from(b in Building, where: b.planet_id == ^planet_id and b.type == "defense_center"),
      set: [level: 1]
    )
  end

  setup %{conn: conn} do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    universe_user = create_universe_user(universe, user)
    planet = create_planet(system, universe_user)
    force_defense_center_level_1(planet.id)

    token = Accounts.generate_user_session_token(user)
    conn = Phoenix.ConnTest.init_test_session(conn, %{"_nexus_downfall_user_token" => token})

    {:ok, conn: conn, planet: planet}
  end

  test "submits a defense order from the defense center", %{conn: conn, planet: planet} do
    {:ok, lv, _html} = live(conn, ~p"/planets/#{planet.id}")

    render_click(lv, "select_building", %{"type" => "defense_center"})
    render_click(lv, "select_tab", %{"tab" => "specific"})
    render_click(lv, "grant_test_resources", %{})

    render_submit(lv, "add_to_defense_order", %{
      "defense_type" => "missile_platform",
      "quantity" => "2"
    })

    html = render_click(lv, "submit_defense_order", %{})

    assert html =~ "Defenses queued successfully!"
    assert html =~ "Missile Platform"

    defense =
      Repo.one!(
        from d in Defense,
          where: d.planet_id == ^planet.id and d.defense_type == "missile_platform"
      )

    assert defense.quantity == 2
  end

  test "shows defense limit errors in the defense center", %{conn: conn, planet: planet} do
    {:ok, lv, _html} = live(conn, ~p"/planets/#{planet.id}")

    render_click(lv, "select_building", %{"type" => "defense_center"})
    render_click(lv, "select_tab", %{"tab" => "specific"})
    render_click(lv, "grant_test_resources", %{})

    render_submit(lv, "add_to_defense_order", %{
      "defense_type" => "planetary_shield_dome",
      "quantity" => "2"
    })

    html = render_click(lv, "submit_defense_order", %{})

    assert html =~ "Defense limit reached for this planet."
  end
end
