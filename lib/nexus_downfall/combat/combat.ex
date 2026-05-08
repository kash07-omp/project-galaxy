defmodule NexusDownfall.Combat do
  @moduledoc """
  Combat context.

  Handles round-based PvP combat resolution: attacker/defender rounds,
  victory/draw/defeat outcomes, loot calculation, population casualties
  and battle report generation.

  ## Phase roadmap
  - Phase 0: Module stub (structure only).
  - Phase 4: Combat engine, deterministic resolution with seed support, reports.
  """

  @max_rounds 6
  @min_hit_chance 0.12
  @max_hit_chance 0.95

  @doc """
  Resolves a deterministic, round-based battle between aggregated unit groups.

  The engine is intentionally O(rounds * groups * target_groups): it never
  expands individual ships or defenses, so a battle with thousands of ships has
  the same simulation cost as a battle with a handful of ships of the same type.
  """
  def resolve_rounds(attacker_groups, defender_groups, opts \\ []) do
    seed = Keyword.get(opts, :seed, 1)
    max_rounds = Keyword.get(opts, :max_rounds, @max_rounds)
    rand_state = :rand.seed_s(:exsss, seed_tuple(seed))

    initial_attacker = normalize_groups(attacker_groups, :attacker)
    initial_defender = normalize_groups(defender_groups, :defender)

    {attacker, defender, rounds, _rand_state} =
      if side_destroyed?(initial_defender) and not side_destroyed?(initial_attacker) do
        overrun_round = %{
          round: 1,
          attacker_losses: %{},
          defender_losses: %{},
          attacker_power: side_power(initial_attacker),
          defender_power: 0,
          no_defenders?: true
        }

        {initial_attacker, initial_defender, [overrun_round], rand_state}
      else
        Enum.reduce_while(
          1..max_rounds,
          {initial_attacker, initial_defender, [], rand_state},
          fn round_number, {attackers, defenders, acc_rounds, rand} ->
            cond do
              side_destroyed?(attackers) or side_destroyed?(defenders) ->
                {:halt, {attackers, defenders, acc_rounds, rand}}

              true ->
                {defender_losses, rand} = side_losses(attackers, defenders, rand)
                {attacker_losses, rand} = side_losses(defenders, attackers, rand)

                attackers_after = apply_losses(attackers, attacker_losses)
                defenders_after = apply_losses(defenders, defender_losses)

                round = %{
                  round: round_number,
                  attacker_losses: losses_by_id(attacker_losses),
                  defender_losses: losses_by_id(defender_losses),
                  attacker_power: side_power(attackers),
                  defender_power: side_power(defenders),
                  no_defenders?: false
                }

                {:cont, {attackers_after, defenders_after, [round | acc_rounds], rand}}
            end
          end
        )
      end

    outcome = outcome(attacker, defender)

    %{
      outcome: outcome,
      rounds: Enum.reverse(rounds),
      attacker_remaining: remaining_by_id(attacker),
      defender_remaining: remaining_by_id(defender),
      attacker_losses: diff_by_id(initial_attacker, attacker),
      defender_losses: diff_by_id(initial_defender, defender),
      attacker_destroyed?: side_destroyed?(attacker),
      defender_destroyed?: side_destroyed?(defender)
    }
  end

  @doc "Builds a combat group for a ship type."
  def ship_group(id, ship_type, quantity, definition, bonuses \\ []) do
    definition
    |> apply_bonuses(ship_type, bonuses)
    |> Map.merge(%{
      id: id,
      unit_type: ship_type,
      kind: :ship,
      class: ship_class(ship_type),
      target_priority: ship_target_priority(ship_type),
      quantity: quantity
    })
  end

  @doc "Builds a combat group for a planetary defense type."
  def defense_group(id, defense_type, quantity, definition, bonuses \\ []) do
    definition
    |> apply_bonuses(defense_type, bonuses)
    |> Map.merge(%{
      id: id,
      unit_type: defense_type,
      kind: :defense,
      class: defense_class(defense_type),
      agility: 0,
      target_priority: Map.get(definition, :target_priority, []),
      quantity: quantity
    })
  end

  @doc "Converts card bonus JSON into stat modifiers understood by the combat engine."
  def bonuses_from_card(nil), do: []
  def bonuses_from_card(%{bonuses: bonuses}), do: bonuses_from_card(bonuses)

  def bonuses_from_card(%{"effects" => effects}) when is_list(effects) do
    Enum.filter(effects, fn
      %{"type" => "stat_bonus"} -> true
      _ -> false
    end)
  end

  def bonuses_from_card(_), do: []

  defp normalize_groups(groups, side) do
    groups
    |> Enum.reject(&(Map.get(&1, :quantity, 0) <= 0))
    |> Enum.map(fn group ->
      group
      |> Map.put(:side, side)
      |> Map.update(:hull, 1, &max(numeric(&1), 1))
      |> Map.update(:shield, 0, &max(numeric(&1), 0))
      |> Map.update(:attack, 0, &max(numeric(&1), 0))
      |> Map.update(:accuracy, 50, &clamp(numeric(&1), 0, 100))
      |> Map.update(:agility, 0, &max(numeric(&1), 0))
      |> Map.update(:target_priority, [], &List.wrap/1)
    end)
    |> Enum.sort_by(&group_sort_key/1)
  end

  defp side_losses(attackers, defenders, rand_state) do
    Enum.reduce(attackers, {%{}, rand_state}, fn attacker, {losses, rand} ->
      targets = prioritized_targets(attacker, defenders, losses)

      {damage, rand} =
        attacker
        |> group_damage(targets)
        |> randomized_damage(rand)

      {updated_losses, _remaining_damage} =
        apply_damage_to_targets(targets, losses, damage)

      {updated_losses, rand}
    end)
  end

  defp prioritized_targets(_attacker, defenders, _losses) when defenders == [] do
    defenders
  end

  defp prioritized_targets(attacker, defenders, losses) do
    priority = attacker.target_priority

    defenders
    |> Enum.reject(fn defender -> remaining_quantity(defender, losses) <= 0 end)
    |> Enum.sort_by(fn defender ->
      priority_index =
        case Enum.find_index(priority, &(&1 == defender.class)) do
          nil -> 99
          index -> index
        end

      {priority_index, group_sort_key(defender)}
    end)
  end

  defp group_damage(%{attack: attack, quantity: quantity}, []), do: attack * quantity

  defp group_damage(%{attack: attack, accuracy: accuracy, quantity: quantity}, targets) do
    average_agility =
      targets
      |> Enum.reduce(0, fn target, acc -> acc + target.agility * target.quantity end)
      |> Kernel./(max(Enum.reduce(targets, 0, &(&1.quantity + &2)), 1))

    hit_chance =
      clamp((accuracy + 25 - average_agility * 0.35) / 100, @min_hit_chance, @max_hit_chance)

    attack * quantity * hit_chance
  end

  defp randomized_damage(damage, rand_state) do
    {roll, rand_state} = :rand.uniform_s(rand_state)
    variance = 0.95 + roll * 0.10
    {damage * variance, rand_state}
  end

  defp apply_damage_to_targets([], losses, damage), do: {losses, damage}

  defp apply_damage_to_targets([target | rest], losses, damage) when damage > 0 do
    current_losses = Map.get(losses, target.id, 0)
    available = target.quantity - current_losses

    if available <= 0 do
      apply_damage_to_targets(rest, losses, damage)
    else
      effective_hp = effective_hp(target)
      destroyed = min(floor(damage / effective_hp), available)
      spent_damage = destroyed * effective_hp

      losses =
        if destroyed > 0 do
          Map.update(losses, target.id, destroyed, &(&1 + destroyed))
        else
          losses
        end

      apply_damage_to_targets(rest, losses, damage - spent_damage)
    end
  end

  defp apply_damage_to_targets(_targets, losses, damage), do: {losses, damage}

  defp apply_losses(groups, losses) do
    Enum.map(groups, fn group ->
      lost = Map.get(losses, group.id, 0)
      %{group | quantity: max(group.quantity - lost, 0)}
    end)
  end

  defp side_destroyed?(groups), do: Enum.all?(groups, &(&1.quantity <= 0))

  defp outcome(attacker, defender) do
    cond do
      side_destroyed?(attacker) and side_destroyed?(defender) -> :draw
      side_destroyed?(defender) -> :attacker_victory
      side_destroyed?(attacker) -> :defender_victory
      true -> :draw
    end
  end

  defp side_power(groups) do
    Enum.reduce(groups, 0, fn group, acc ->
      acc + trunc(group.quantity * (group.attack + group.hull + group.shield))
    end)
  end

  defp remaining_quantity(group, losses), do: group.quantity - Map.get(losses, group.id, 0)
  defp effective_hp(group), do: max(group.hull + group.shield, 1)

  defp remaining_by_id(groups), do: Map.new(groups, &{&1.id, &1.quantity})

  defp losses_by_id(losses), do: Map.reject(losses, fn {_id, quantity} -> quantity <= 0 end)

  defp diff_by_id(before_groups, after_groups) do
    after_by_id = remaining_by_id(after_groups)

    before_groups
    |> Map.new(fn group -> {group.id, group.quantity - Map.get(after_by_id, group.id, 0)} end)
    |> losses_by_id()
  end

  defp apply_bonuses(definition, unit_type, bonuses) do
    Enum.reduce(bonuses, definition, fn bonus, acc ->
      affected_types = Map.get(bonus, "ship_types", [])
      affects_unit? = affected_types in [nil, []] or unit_type in affected_types

      if affects_unit? do
        stat = normalize_bonus_stat(Map.get(bonus, "stat"))
        modifier = Map.get(bonus, "modifier")
        value = numeric(Map.get(bonus, "value", 0))

        if stat && Map.has_key?(acc, stat) do
          Map.update!(acc, stat, fn current ->
            case modifier do
              "flat" -> current + value
              _ -> current * (1 + value / 100)
            end
          end)
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp normalize_bonus_stat("evasion"), do: :agility
  defp normalize_bonus_stat("agility"), do: :agility
  defp normalize_bonus_stat("attack"), do: :attack
  defp normalize_bonus_stat("shield"), do: :shield
  defp normalize_bonus_stat("hull"), do: :hull
  defp normalize_bonus_stat("accuracy"), do: :accuracy
  defp normalize_bonus_stat(_), do: nil

  defp ship_class(ship_type)
       when ship_type in ["light_freighter", "heavy_freighter", "colonizer"], do: "Civil"

  defp ship_class(ship_type) when ship_type in ["light_fighter"], do: "Light"
  defp ship_class(ship_type) when ship_type in ["corvette", "missile_corvette"], do: "Medium"
  defp ship_class(ship_type) when ship_type in ["bomber", "aphelion"], do: "Siege"
  defp ship_class(ship_type) when ship_type in ["blocker", "carrier", "ew_cruiser"], do: "Support"
  defp ship_class(ship_type) when ship_type in ["battleship", "leviathan"], do: "Capital"
  defp ship_class(ship_type) when ship_type in ["exodus"], do: "Conquest"
  defp ship_class(_ship_type), do: "Heavy"

  defp defense_class("planetary_shield_dome"), do: "Shield"
  defp defense_class("anti_siege_matrix"), do: "Support"
  defp defense_class("orbital_interdiction_platform"), do: "Support"
  defp defense_class("planetary_defense_bastion"), do: "Conquest"

  defp defense_class(defense_type) when defense_type in ["plasma_turret", "gauss_cannon"],
    do: "Heavy"

  defp defense_class(_defense_type), do: "Light"

  defp ship_target_priority(ship_type)
       when ship_type in ["light_freighter", "heavy_freighter", "colonizer"],
       do: ["Light", "Civil", "Medium"]

  defp ship_target_priority(ship_type) when ship_type in ["light_fighter", "corvette"],
    do: ["Civil", "Light", "Medium", "Support"]

  defp ship_target_priority(ship_type)
       when ship_type in ["missile_corvette", "bomber", "aphelion"],
       do: ["Shield", "Support", "Light", "Heavy", "Capital"]

  defp ship_target_priority(ship_type)
       when ship_type in ["heavy_fighter", "frigate", "light_destroyer", "cruiser"],
       do: ["Medium", "Light", "Heavy", "Civil"]

  defp ship_target_priority(ship_type) when ship_type in ["battleship", "leviathan"],
    do: ["Capital", "Heavy", "Support", "Shield"]

  defp ship_target_priority("exodus"), do: ["Conquest", "Shield", "Support", "Heavy"]
  defp ship_target_priority(_ship_type), do: ["Light", "Medium", "Heavy", "Civil"]

  defp group_sort_key(group),
    do: {group.kind, group.class, to_string(group.unit_type), inspect(group.id)}

  defp seed_tuple(seed) when is_integer(seed) do
    {seed, seed * 1_103_515 + 12_345, seed * 2_147_483 + 54_321}
  end

  defp seed_tuple({a, b, c}), do: {a, b, c}
  defp seed_tuple(_seed), do: {1, 2, 3}

  defp numeric(value) when is_integer(value) or is_float(value), do: value

  defp numeric(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> 0
    end
  end

  defp numeric(_), do: 0

  defp clamp(value, min, max), do: value |> Kernel.max(min) |> Kernel.min(max)
end
