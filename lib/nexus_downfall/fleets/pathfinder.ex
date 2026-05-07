defmodule NexusDownfall.Fleets.Pathfinder do
  @moduledoc """
  Pure A* pathfinder for fleet routes between solar systems.

  The graph is intentionally plain data so it can be tested without the
  database and reused later by Oban fleet workers.

  Systems must expose an `id`; coordinates (`x`, `y`) are optional and used only
  for the heuristic. Hyperlinks may be `{a, b}` tuples or structs/maps with
  `system_a_id` and `system_b_id`.
  """

  @type system_id :: term()
  @type system :: map()
  @type edge :: {system_id(), system_id()} | map()

  @doc """
  Returns the shortest route from `start_id` to `goal_id`.

  The route includes both endpoints. The cost is one hop per hyperlink, matching
  the MVP fleet rule of travelling across connected systems. Ties are resolved
  deterministically by system id.
  """
  @spec shortest_path([system()], [edge()], system_id(), system_id()) ::
          {:ok, [system_id()]} | {:error, :unknown_system | :no_route}
  def shortest_path(systems, _hyperlinks, start_id, goal_id) when start_id == goal_id do
    systems_by_id = systems_by_id(systems)

    if Map.has_key?(systems_by_id, start_id) do
      {:ok, [start_id]}
    else
      {:error, :unknown_system}
    end
  end

  def shortest_path(systems, hyperlinks, start_id, goal_id) do
    systems_by_id = systems_by_id(systems)

    cond do
      not Map.has_key?(systems_by_id, start_id) -> {:error, :unknown_system}
      not Map.has_key?(systems_by_id, goal_id) -> {:error, :unknown_system}
      true -> astar(systems_by_id, build_graph(systems_by_id, hyperlinks), start_id, goal_id)
    end
  end

  defp astar(systems_by_id, graph, start_id, goal_id) do
    max_edge_distance = max_edge_distance(systems_by_id, graph)

    search(%{
      systems_by_id: systems_by_id,
      graph: graph,
      goal_id: goal_id,
      max_edge_distance: max_edge_distance,
      open: MapSet.new([start_id]),
      came_from: %{},
      g_score: %{start_id => 0.0},
      f_score: %{start_id => heuristic(systems_by_id, start_id, goal_id, max_edge_distance)}
    })
  end

  defp search(%{open: open} = state) do
    if MapSet.size(open) == 0 do
      {:error, :no_route}
    else
      current = best_open_system(state)

      if current == state.goal_id do
        {:ok, reconstruct_path(state.came_from, current)}
      else
        state
        |> close_current(current)
        |> visit_neighbors(current)
        |> search()
      end
    end
  end

  defp best_open_system(%{open: open, f_score: f_score, g_score: g_score}) do
    Enum.min_by(open, fn id ->
      {Map.get(f_score, id, :infinity), Map.get(g_score, id, :infinity), stable_id(id)}
    end)
  end

  defp close_current(state, current) do
    %{state | open: MapSet.delete(state.open, current)}
  end

  defp visit_neighbors(state, current) do
    state.graph
    |> Map.get(current, MapSet.new())
    |> Enum.sort_by(&stable_id/1)
    |> Enum.reduce(state, fn neighbor, acc ->
      tentative_g_score = Map.fetch!(acc.g_score, current) + 1.0
      previous_g_score = Map.get(acc.g_score, neighbor, :infinity)

      if better_route?(
           tentative_g_score,
           previous_g_score,
           current,
           Map.get(acc.came_from, neighbor)
         ) do
        update_route(acc, current, neighbor, tentative_g_score)
      else
        acc
      end
    end)
  end

  defp better_route?(tentative, :infinity, _current, _previous_parent), do: is_number(tentative)

  defp better_route?(tentative, previous, _current, _previous_parent) when tentative < previous,
    do: true

  defp better_route?(tentative, previous, current, previous_parent) when tentative == previous do
    previous_parent == nil or stable_id(current) < stable_id(previous_parent)
  end

  defp better_route?(_tentative, _previous, _current, _previous_parent), do: false

  defp update_route(state, current, neighbor, tentative_g_score) do
    f_score =
      tentative_g_score +
        heuristic(state.systems_by_id, neighbor, state.goal_id, state.max_edge_distance)

    %{
      state
      | open: MapSet.put(state.open, neighbor),
        came_from: Map.put(state.came_from, neighbor, current),
        g_score: Map.put(state.g_score, neighbor, tentative_g_score),
        f_score: Map.put(state.f_score, neighbor, f_score)
    }
  end

  defp reconstruct_path(came_from, current) do
    case Map.fetch(came_from, current) do
      {:ok, previous} -> reconstruct_path(came_from, previous) ++ [current]
      :error -> [current]
    end
  end

  defp systems_by_id(systems) do
    Map.new(systems, fn system -> {field(system, :id), system} end)
  end

  defp build_graph(systems_by_id, hyperlinks) do
    initial_graph = Map.new(Map.keys(systems_by_id), fn id -> {id, MapSet.new()} end)

    Enum.reduce(hyperlinks, initial_graph, fn hyperlink, graph ->
      {a, b} = edge_ids(hyperlink)

      if Map.has_key?(systems_by_id, a) and Map.has_key?(systems_by_id, b) do
        graph
        |> Map.update!(a, &MapSet.put(&1, b))
        |> Map.update!(b, &MapSet.put(&1, a))
      else
        graph
      end
    end)
  end

  defp edge_ids({a, b}), do: {a, b}
  defp edge_ids([a, b]), do: {a, b}
  defp edge_ids(edge), do: {field(edge, :system_a_id), field(edge, :system_b_id)}

  defp heuristic(systems_by_id, a, b, max_edge_distance) do
    if max_edge_distance > 0 do
      coordinate_distance(Map.fetch!(systems_by_id, a), Map.fetch!(systems_by_id, b)) /
        max_edge_distance
    else
      0.0
    end
  end

  defp max_edge_distance(_systems_by_id, graph) when map_size(graph) == 0, do: 0.0

  defp max_edge_distance(systems_by_id, graph) do
    distances =
      graph
      |> Enum.flat_map(fn {a, neighbors} -> Enum.map(neighbors, &{a, &1}) end)
      |> Enum.map(fn {a, b} ->
        coordinate_distance(Map.fetch!(systems_by_id, a), Map.fetch!(systems_by_id, b))
      end)

    case distances do
      [] -> 0.0
      _ -> Enum.max(distances)
    end
  end

  defp coordinate_distance(a, b) do
    with ax when is_number(ax) <- field(a, :x),
         ay when is_number(ay) <- field(a, :y),
         bx when is_number(bx) <- field(b, :x),
         by when is_number(by) <- field(b, :y) do
      :math.sqrt(:math.pow(ax - bx, 2) + :math.pow(ay - by, 2))
    else
      _ -> 0.0
    end
  end

  defp field(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, Atom.to_string(key))
  end

  defp stable_id(id) when is_integer(id), do: id
  defp stable_id(id), do: inspect(id)
end
