defmodule NexusDownfall.UniverseUserTest do
  use NexusDownfall.DataCase, async: true

  alias NexusDownfall.Accounts
  alias NexusDownfall.Repo
  alias NexusDownfall.Universe
  alias NexusDownfall.Universe.UniverseRecord

  defp create_user do
    uniq = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        account_name: "p#{uniq}",
        email: "player#{uniq}@example.com",
        password: "correcthorsebatterystaple!"
      })

    user
  end

  defp create_universe do
    {:ok, u} =
      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Test Universe",
        slug: "test-#{System.unique_integer()}"
      })
      |> NexusDownfall.Repo.insert()

    u
  end

  describe "join_universe/3" do
    test "creates a universe_user" do
      user = create_user()
      universe = create_universe()
      assert {:ok, uu} = Accounts.join_universe(user, universe, %{username: "Overlord"})
      assert uu.user_id == user.id
      assert uu.universe_id == universe.id
      assert uu.username == "Overlord"
    end

    test "rejects duplicate join" do
      user = create_user()
      universe = create_universe()
      {:ok, _} = Accounts.join_universe(user, universe, %{username: "One"})
      assert {:error, cs} = Accounts.join_universe(user, universe, %{username: "Two"})
      assert %{user_id: [_]} = errors_on(cs)
    end

    test "rejects duplicate username within same universe" do
      universe = create_universe()
      u1 = create_user()
      u2 = create_user()
      {:ok, _} = Accounts.join_universe(u1, universe, %{username: "Samename"})
      assert {:error, cs} = Accounts.join_universe(u2, universe, %{username: "Samename"})
      # Ecto maps the unique constraint to the first listed field (universe_id)
      assert %{universe_id: [_]} = errors_on(cs)
    end

    test "allows same username in different universes" do
      u1 = create_user()
      univ_a = create_universe()
      univ_b = create_universe()
      assert {:ok, _} = Accounts.join_universe(u1, univ_a, %{username: "Nomad"})
      assert {:ok, _} = Accounts.join_universe(u1, univ_b, %{username: "Nomad"})
    end

    test "normalizes legacy invalid account names when joining" do
      user = create_user()
      universe = create_universe()

      Repo.update_all(
        from(u in NexusDownfall.Accounts.User, where: u.id == ^user.id),
        set: [account_name: "martinpardo.oscar"]
      )

      user = Repo.get!(NexusDownfall.Accounts.User, user.id)

      assert {:ok, uu} = Accounts.join_universe(user, universe, %{})
      assert uu.username == "martinpardooscar"
    end
  end

  describe "list_universe_memberships/1" do
    test "returns all memberships for a user" do
      user = create_user()
      u1 = create_universe()
      u2 = create_universe()
      Accounts.join_universe(user, u1, %{username: "Alpha"})
      Accounts.join_universe(user, u2, %{username: "Beta"})

      memberships = Accounts.list_universe_memberships(user.id)
      assert length(memberships) == 2
    end
  end

  describe "list_open_universes/0" do
    test "only returns universes with status open" do
      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Open",
        slug: "open-#{System.unique_integer()}",
        status: "open"
      })
      |> NexusDownfall.Repo.insert!()

      %UniverseRecord{}
      |> UniverseRecord.creation_changeset(%{
        name: "Running",
        slug: "run-#{System.unique_integer()}",
        status: "running"
      })
      |> NexusDownfall.Repo.insert!()

      open = Universe.list_open_universes()
      assert Enum.all?(open, &(&1.status == "open"))
    end
  end
end
