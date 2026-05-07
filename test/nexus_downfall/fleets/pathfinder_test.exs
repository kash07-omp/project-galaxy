defmodule NexusDownfall.Fleets.PathfinderTest do
  use ExUnit.Case, async: true

  alias NexusDownfall.Fleets.Pathfinder

  defp systems(ids) do
    Enum.map(ids, fn id -> %{id: id, x: id * 10.0, y: 0.0} end)
  end

  describe "shortest_path/4" do
    test "returns the minimum-hop route between connected systems" do
      systems = systems(1..5)
      hyperlinks = [{1, 2}, {2, 5}, {1, 3}, {3, 4}, {4, 5}]

      assert {:ok, [1, 2, 5]} = Pathfinder.shortest_path(systems, hyperlinks, 1, 5)
    end

    test "returns no_route when the target cannot be reached" do
      systems = systems(1..4)
      hyperlinks = [{1, 2}, {3, 4}]

      assert {:error, :no_route} = Pathfinder.shortest_path(systems, hyperlinks, 1, 4)
    end

    test "resolves equal-length routes deterministically by lower system id" do
      systems = Enum.map(1..4, fn id -> %{id: id} end)
      hyperlinks = [{1, 3}, {3, 4}, {1, 2}, {2, 4}]

      assert {:ok, [1, 2, 4]} = Pathfinder.shortest_path(systems, hyperlinks, 1, 4)
    end

    test "accepts map-shaped hyperlinks from Ecto schemas" do
      systems = systems(1..3)
      hyperlinks = [%{system_a_id: 1, system_b_id: 2}, %{system_a_id: 2, system_b_id: 3}]

      assert {:ok, [1, 2, 3]} = Pathfinder.shortest_path(systems, hyperlinks, 1, 3)
    end

    test "returns unknown_system when either endpoint is missing" do
      assert {:error, :unknown_system} = Pathfinder.shortest_path(systems(1..2), [{1, 2}], 1, 99)
    end

    test "returns the singleton route when start and target are the same" do
      assert {:ok, [1]} = Pathfinder.shortest_path(systems(1..2), [{1, 2}], 1, 1)
    end
  end
end
