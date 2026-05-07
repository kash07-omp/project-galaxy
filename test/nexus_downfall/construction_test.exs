defmodule NexusDownfall.Planets.ConstructionTest do
  @moduledoc """
  Phase 2 integration tests for the construction queue:
  start_construction, planet_busy, insufficient_resources, BuildCompleteWorker.
  """
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  import Ecto.Query

  alias NexusDownfall.Repo
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, ProductionEngine}
  alias NexusDownfall.Workers.BuildCompleteWorker

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp create_universe do
    {:ok, universe} =
      %NexusDownfall.Universe.UniverseRecord{}
      |> NexusDownfall.Universe.UniverseRecord.creation_changeset(%{
        name: "Test",
        slug: "test-#{System.unique_integer([:positive])}",
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
      NexusDownfall.Accounts.register_user(%{
        email: "test-#{System.unique_integer([:positive])}@test.com",
        password: "supersecretpassword123"
      })

    user
  end

  defp create_universe_user(universe, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, uu} =
      %NexusDownfall.Accounts.UniverseUser{}
      |> NexusDownfall.Accounts.UniverseUser.join_changeset(%{
        universe_id: universe.id,
        user_id: user.id,
        username: "Tester#{System.unique_integer([:positive])}",
        joined_at: now
      })
      |> Repo.insert()

    uu
  end

  defp create_planet(system, universe_user) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: "TestPlanet",
        orbit_position: 3,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    planet
  end

  defp setup_planet(_ctx) do
    universe = create_universe()
    galaxy = create_galaxy(universe)
    system = create_system(galaxy)
    user = create_user()
    uu = create_universe_user(universe, user)
    planet = create_planet(system, uu)

    # Give the planet plenty of resources
    Repo.update_all(
      from(p in NexusDownfall.Planets.Planet, where: p.id == ^planet.id),
      set: [raw_materials: 999_999, microchips: 999_999, hydrogen: 999_999, food: 999_999]
    )

    planet = Planets.get_planet!(planet.id)
    {:ok, planet: planet, user: user}
  end

  # ---------------------------------------------------------------------------
  # start_construction/2 — success
  # ---------------------------------------------------------------------------

  describe "start_construction/2 success" do
    setup :setup_planet

    test "returns {:ok, building} for a valid upgrade", %{planet: planet} do
      # Oban is :inline in test env — job runs synchronously on insert
      assert {:ok, _building} = Planets.start_construction(planet.id, "mine_raw")
    end

    test "building reaches level 1 after construction completes (inline)", %{planet: planet} do
      {:ok, building} = Planets.start_construction(planet.id, "mine_raw")
      # With :inline Oban, the job runs synchronously — re-fetch to see final DB state
      updated = Repo.get!(Building, building.id)
      assert updated.level == 1
      assert is_nil(updated.construction_finish_at)
    end

    test "schedules an Oban job (manual mode)", %{planet: planet} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, building} = Planets.start_construction(planet.id, "mine_raw")
        assert_enqueued(worker: BuildCompleteWorker, args: %{"building_id" => building.id})
      end)
    end

    test "deducts resources from the planet", %{planet: planet} do
      cost = ProductionEngine.build_cost("mine_raw", 1)
      planet_before = Repo.get!(NexusDownfall.Planets.Planet, planet.id)

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _building} = Planets.start_construction(planet.id, "mine_raw")
      end)

      planet_after = Repo.get!(NexusDownfall.Planets.Planet, planet.id)
      assert planet_after.raw_materials == planet_before.raw_materials - cost.raw_materials
    end
  end

  # ---------------------------------------------------------------------------
  # start_construction/2 — planet already busy
  # ---------------------------------------------------------------------------

  describe "start_construction/2 with planet busy" do
    setup :setup_planet

    test "returns :planet_busy when another building is under construction", %{planet: planet} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = Planets.start_construction(planet.id, "mine_raw")
        assert {:error, :planet_busy} = Planets.start_construction(planet.id, "farm")
      end)
    end

    test "returns :already_constructing for same building twice", %{planet: planet} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} = Planets.start_construction(planet.id, "mine_raw")
        assert {:error, :already_constructing} = Planets.start_construction(planet.id, "mine_raw")
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # start_construction/2 — insufficient resources
  # ---------------------------------------------------------------------------

  describe "start_construction/2 with insufficient resources" do
    setup :setup_planet

    test "returns :insufficient_resources when planet is broke", %{planet: planet} do
      # Drain all resources
      Repo.update_all(
        from(p in NexusDownfall.Planets.Planet, where: p.id == ^planet.id),
        set: [raw_materials: 0, microchips: 0, hydrogen: 0, food: 0]
      )

      assert {:error, :insufficient_resources} =
               Planets.start_construction(planet.id, "mine_raw")
    end

    test "does not enqueue an Oban job on insufficient resources", %{planet: planet} do
      Repo.update_all(
        from(p in NexusDownfall.Planets.Planet, where: p.id == ^planet.id),
        set: [raw_materials: 0, microchips: 0, hydrogen: 0, food: 0]
      )

      Planets.start_construction(planet.id, "mine_raw")
      refute_enqueued(worker: BuildCompleteWorker)
    end
  end

  # ---------------------------------------------------------------------------
  # BuildCompleteWorker — completion
  # ---------------------------------------------------------------------------

  describe "BuildCompleteWorker.perform/1" do
    setup :setup_planet

    test "increments building level on completion", %{planet: planet} do
      # Use manual mode so the job does NOT run inline
      building =
        Oban.Testing.with_testing_mode(:manual, fn ->
          {:ok, b} = Planets.start_construction(planet.id, "mine_raw")
          b
        end)

      assert building.level == 0

      assert :ok = perform_job(BuildCompleteWorker, %{"building_id" => building.id})

      updated = Repo.get!(Building, building.id)
      assert updated.level == 1
      assert is_nil(updated.construction_finish_at)
    end

    test "clears construction_finish_at after completion", %{planet: planet} do
      building =
        Oban.Testing.with_testing_mode(:manual, fn ->
          {:ok, b} = Planets.start_construction(planet.id, "mine_raw")
          b
        end)

      assert :ok = perform_job(BuildCompleteWorker, %{"building_id" => building.id})

      updated = Repo.get!(Building, building.id)
      assert is_nil(updated.construction_finish_at)
    end

    test "returns :ok (not error) for missing building_id — idempotent on deletion" do
      # Worker is designed to return :ok when building is deleted (prevent Oban retries)
      assert :ok = perform_job(BuildCompleteWorker, %{"building_id" => 999_999})
    end

    test "is idempotent when the same completion job is performed twice", %{planet: planet} do
      building =
        Oban.Testing.with_testing_mode(:manual, fn ->
          {:ok, b} = Planets.start_construction(planet.id, "mine_raw")
          b
        end)

      assert :ok = perform_job(BuildCompleteWorker, %{"building_id" => building.id})
      assert :ok = perform_job(BuildCompleteWorker, %{"building_id" => building.id})

      updated = Repo.get!(Building, building.id)
      assert updated.level == 1
      assert is_nil(updated.construction_finish_at)
    end

    test "reconcile_due_constructions/1 completes expired work when async job is still pending", %{planet: planet} do
      building =
        Oban.Testing.with_testing_mode(:manual, fn ->
          {:ok, b} = Planets.start_construction(planet.id, "mine_raw")
          b
        end)

      past_time = DateTime.utc_now() |> DateTime.add(-5, :second) |> DateTime.truncate(:second)

      Repo.update_all(
        from(b in Building, where: b.id == ^building.id),
        set: [construction_finish_at: past_time]
      )

      assert :ok = Planets.reconcile_due_constructions(planet.id)

      updated = Repo.get!(Building, building.id)
      assert updated.level == 1
      assert is_nil(updated.construction_finish_at)
    end
  end
end
