defmodule NexusDownfall.Planets.DefensesTest do
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  import Ecto.Query

  alias NexusDownfall.Accounts
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Defense, DefenseQueueItem, Defenses, Planet}
  alias NexusDownfall.Repo
  alias NexusDownfall.Workers.DefenseConstructionCompleteWorker

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Defense Test",
        slug: "defense-test-#{System.unique_integer([:positive])}",
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
        email: "defense-#{System.unique_integer([:positive])}@test.com",
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
        username: "Defender#{System.unique_integer([:positive])}",
        joined_at: now
      })
      |> Repo.insert()

    universe_user
  end

  defp create_planet(system, universe_user) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: "Defense Home",
        orbit_position: 2,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    Repo.update_all(
      from(p in Planet, where: p.id == ^planet.id),
      set: [raw_materials: 1_000_000, microchips: 1_000_000, hydrogen: 1_000_000]
    )

    Repo.get!(Planet, planet.id)
  end

  defp force_defense_center_level(planet_id, level) do
    Repo.update_all(
      from(b in Building, where: b.planet_id == ^planet_id and b.type == "defense_center"),
      set: [level: level]
    )
  end

  setup do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    universe_user = create_universe_user(universe, user)
    planet = create_planet(system, universe_user)

    {:ok, user: user, planet: planet}
  end

  test "requires defense center level 1 before queueing defenses", %{user: user, planet: planet} do
    assert {:error, :defense_center_required} =
             Defenses.enqueue_defense_construction_for_user(planet.id, user.id, %{
               "defense_type" => "missile_platform",
               "quantity" => "1"
             })
  end

  test "queues and completes defenses through Oban inline mode", %{user: user, planet: planet} do
    force_defense_center_level(planet.id, 1)

    assert {:ok, item} =
             Defenses.enqueue_defense_construction_for_user(planet.id, user.id, %{
               "defense_type" => "missile_platform",
               "quantity" => "3"
             })

    assert item.defense_type == "missile_platform"

    defense =
      Repo.one!(
        from d in Defense,
          where: d.planet_id == ^planet.id and d.defense_type == "missile_platform"
      )

    assert defense.quantity == 3
  end

  test "deducts the full batch cost when queueing", %{user: user, planet: planet} do
    force_defense_center_level(planet.id, 1)

    before = Repo.get!(Planet, planet.id)
    cost = Defenses.defense_total_cost("gauss_cannon", 2)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert {:ok, _item} =
               Defenses.enqueue_defense_construction_for_user(planet.id, user.id, %{
                 "defense_type" => "gauss_cannon",
                 "quantity" => "2"
               })
    end)

    after_planet = Repo.get!(Planet, planet.id)
    assert after_planet.raw_materials == before.raw_materials - cost.raw_materials
    assert after_planet.microchips == before.microchips - cost.microchips
    assert after_planet.hydrogen == before.hydrogen - cost.hydrogen
  end

  test "manual worker completion increments one defense and leaves remaining batch active", %{
    user: user,
    planet: planet
  } do
    force_defense_center_level(planet.id, 1)

    item =
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, queued} =
          Defenses.enqueue_defense_construction_for_user(planet.id, user.id, %{
            "defense_type" => "light_laser_tower",
            "quantity" => "2"
          })

        queued
      end)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok = perform_job(DefenseConstructionCompleteWorker, %{"queue_item_id" => item.id})
    end)

    defense =
      Repo.one!(
        from d in Defense,
          where: d.planet_id == ^planet.id and d.defense_type == "light_laser_tower"
      )

    queue_item = Repo.get!(DefenseQueueItem, item.id)
    assert defense.quantity == 1
    assert queue_item.status == "building"
    assert queue_item.quantity == 1
  end

  test "enforces critical infrastructure limits", %{user: user, planet: planet} do
    force_defense_center_level(planet.id, 1)

    assert {:error, :defense_limit_reached} =
             Defenses.enqueue_defense_construction_for_user(planet.id, user.id, %{
               "defense_type" => "planetary_shield_dome",
               "quantity" => "2"
             })
  end
end
