defmodule NexusDownfall.CombatTest do
  use ExUnit.Case, async: true

  alias NexusDownfall.Combat

  test "empty defense resolves as attacker victory without losses" do
    attackers = [
      Combat.ship_group(
        {:fleet_ship, 1},
        "corvette",
        3,
        %{hull: 220, shield: 45, attack: 80, accuracy: 60, agility: 62},
        []
      )
    ]

    result = Combat.resolve_rounds(attackers, [], seed: 42)

    assert result.outcome == :attacker_victory
    assert result.attacker_losses == %{}
    assert result.defender_losses == %{}
  end

  test "fixed seeds produce identical round and loss results" do
    attackers = [
      Combat.ship_group(
        {:fleet_ship, 1},
        "corvette",
        12,
        %{hull: 220, shield: 45, attack: 80, accuracy: 60, agility: 62},
        []
      )
    ]

    defenders = [
      Combat.defense_group(
        {:defense, 1},
        "missile_platform",
        8,
        %{hull: 160, shield: 15, attack: 55, accuracy: 55, target_priority: ["Light", "Medium"]},
        []
      )
    ]

    first = Combat.resolve_rounds(attackers, defenders, seed: 777)
    second = Combat.resolve_rounds(attackers, defenders, seed: 777)

    assert first == second
    assert first.outcome in [:attacker_victory, :defender_victory, :draw]
    assert Enum.all?(Map.values(first.attacker_remaining), &(&1 >= 0))
    assert Enum.all?(Map.values(first.defender_remaining), &(&1 >= 0))
  end

  test "admiral evasion bonus reduces or preserves losses under the same seed" do
    base_attackers = [
      Combat.ship_group(
        {:fleet_ship, 1},
        "light_fighter",
        40,
        %{hull: 90, shield: 20, attack: 35, accuracy: 68, agility: 85},
        []
      )
    ]

    boosted_attackers = [
      Combat.ship_group(
        {:fleet_ship, 1},
        "light_fighter",
        40,
        %{hull: 90, shield: 20, attack: 35, accuracy: 68, agility: 85},
        [
          %{
            "type" => "stat_bonus",
            "stat" => "evasion",
            "ship_types" => ["light_fighter"],
            "modifier" => "percentage",
            "value" => 25
          }
        ]
      )
    ]

    defenders = [
      Combat.defense_group(
        {:defense, 1},
        "light_laser_tower",
        20,
        %{hull: 180, shield: 25, attack: 75, accuracy: 75, target_priority: ["Light"]},
        []
      )
    ]

    base = Combat.resolve_rounds(base_attackers, defenders, seed: 100)
    boosted = Combat.resolve_rounds(boosted_attackers, defenders, seed: 100)

    assert Map.get(boosted.attacker_losses, {:fleet_ship, 1}, 0) <=
             Map.get(base.attacker_losses, {:fleet_ship, 1}, 0)
  end
end
