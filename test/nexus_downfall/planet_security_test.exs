defmodule NexusDownfall.Planets.SecurityTest do
  use NexusDownfall.DataCase, async: true
  use Oban.Testing, repo: NexusDownfall.Repo

  import Ecto.Query

  alias NexusDownfall.Accounts
  alias NexusDownfall.Accounts.UniverseUser
  alias NexusDownfall.Planets
  alias NexusDownfall.Planets.{Building, Planet}
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe.{Galaxy, SolarSystem, UniverseRecord}

  defp create_universe do
    %UniverseRecord{}
    |> UniverseRecord.creation_changeset(%{
      name: "Security Test",
      slug: "security-#{System.unique_integer([:positive])}"
    })
    |> Repo.insert!()
  end

  defp create_system(universe) do
    galaxy =
      %Galaxy{}
      |> Galaxy.changeset(%{number: 1, universe_id: universe.id})
      |> Repo.insert!()

    %SolarSystem{}
    |> SolarSystem.changeset(%{number: 1, galaxy_id: galaxy.id, x: 0.0, y: 0.0})
    |> Repo.insert!()
  end

  defp create_user(email_prefix) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "#{email_prefix}-#{System.unique_integer([:positive])}@example.com",
        password: "supersecretpassword123"
      })

    user
  end

  defp create_universe_user(universe, user, username) do
    %UniverseUser{}
    |> UniverseUser.join_changeset(%{
      universe_id: universe.id,
      user_id: user.id,
      username: username,
      joined_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  defp create_owned_planet(system, universe_user) do
    {:ok, planet} =
      Planets.create_initial_planet(%{
        name: "Owned",
        orbit_position: 1,
        region: 1,
        solar_system_id: system.id,
        universe_user_id: universe_user.id
      })

    Repo.update_all(
      from(p in Planet, where: p.id == ^planet.id),
      set: [raw_materials: 999_999, microchips: 999_999, hydrogen: 999_999, food: 999_999]
    )

    Planets.get_planet!(planet.id)
  end

  defp create_unclaimed_slot(universe, system, orbit) do
    %Planet{}
    |> Planet.initial_changeset(%{
      name: "Slot #{orbit}",
      orbit_position: orbit,
      region: 1,
      slot_type: "planet",
      planet_subtype: "rocky",
      universe_id: universe.id,
      solar_system_id: system.id,
      last_tick_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  describe "planet ownership" do
    test "get_user_planet!/2 only returns planets owned by that global user" do
      universe = create_universe()
      system = create_system(universe)
      owner = create_user("owner")
      other = create_user("other")
      owner_uu = create_universe_user(universe, owner, "Owner")
      planet = create_owned_planet(system, owner_uu)

      assert Planets.get_user_planet!(planet.id, owner.id).id == planet.id

      assert_raise Ecto.NoResultsError, fn ->
        Planets.get_user_planet!(planet.id, other.id)
      end
    end

    test "start_construction_for_user/3 rejects non-owners without mutating the planet" do
      universe = create_universe()
      system = create_system(universe)
      owner = create_user("owner")
      other = create_user("other")
      owner_uu = create_universe_user(universe, owner, "Owner")
      planet = create_owned_planet(system, owner_uu)

      assert {:error, :not_found} =
               Planets.start_construction_for_user(planet.id, other.id, "mine_raw")

      mine = Repo.get_by!(Building, planet_id: planet.id, type: "mine_raw")
      assert mine.level == 0
      assert is_nil(mine.construction_finish_at)
    end

    test "start_construction_for_user/3 allows the owner" do
      universe = create_universe()
      system = create_system(universe)
      owner = create_user("owner")
      owner_uu = create_universe_user(universe, owner, "Owner")
      planet = create_owned_planet(system, owner_uu)

      assert {:ok, _building} =
               Planets.start_construction_for_user(planet.id, owner.id, "mine_raw")
    end
  end

  describe "claim_planet_slot/3" do
    test "claims the first available slot and then the next one" do
      universe = create_universe()
      system = create_system(universe)
      player = create_user("claimer")
      uu = create_universe_user(universe, player, "Claimer")
      create_unclaimed_slot(universe, system, 1)
      create_unclaimed_slot(universe, system, 2)

      assert {:ok, first} = Planets.claim_planet_slot(system.id, uu.id, "First Home")
      assert first.orbit_position == 1

      assert {:ok, second} = Planets.claim_planet_slot(system.id, uu.id, "Second Home")
      assert second.orbit_position == 2
    end

    test "returns no_available_slots when every planet slot is occupied" do
      universe = create_universe()
      system = create_system(universe)
      player = create_user("full")
      uu = create_universe_user(universe, player, "Full")
      create_unclaimed_slot(universe, system, 1)
      assert {:ok, _planet} = Planets.claim_planet_slot(system.id, uu.id, "Only Home")

      assert {:error, :no_available_slots} =
               Planets.claim_planet_slot(system.id, uu.id, "Too Late")
    end
  end
end
