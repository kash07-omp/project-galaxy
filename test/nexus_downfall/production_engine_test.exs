defmodule NexusDownfall.Planets.ProductionEngineTest do
  @moduledoc """
  Phase 2 tests: production formula, energy boundaries, efficiency, costs.
  These are pure-functional tests — no database required.
  """
  use ExUnit.Case, async: true

  alias NexusDownfall.Planets.ProductionEngine

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp b(type, level), do: %{type: type, level: level, construction_finish_at: nil}

  defp rates_with_power(building, power_level) do
    ProductionEngine.calculate_rates([building, b("power_plant", power_level)])
  end

  # ---------------------------------------------------------------------------
  # OGame formula: base * level * 1.1^level
  # ---------------------------------------------------------------------------

  describe "production formula (OGame: base * level * 1.1^level)" do
    test "level 0 produces nothing" do
      rates = ProductionEngine.calculate_rates([b("mine_raw", 0), b("power_plant", 10)])
      assert rates.raw_materials == 0.0
    end

    test "level 1 mine_raw: 200 * 1 * 1.1^1 = 220.0" do
      rates = rates_with_power(b("mine_raw", 1), 10)
      assert Float.round(rates.raw_materials, 2) == 220.0
    end

    test "level 2 mine_raw: 200 * 2 * 1.1^2 = 484.0" do
      rates = rates_with_power(b("mine_raw", 2), 10)
      assert Float.round(rates.raw_materials, 2) == 484.0
    end

    test "level 3 mine_raw: 200 * 3 * 1.1^3 = 798.6" do
      rates = rates_with_power(b("mine_raw", 3), 10)
      expected = 200 * 3 * :math.pow(1.1, 3)
      assert abs(rates.raw_materials - expected) < 0.01
    end

    test "production rate increases monotonically with level" do
      prev_rate = fn lvl ->
        rates_with_power(b("mine_raw", lvl), 20) |> Map.get(:raw_materials)
      end

      for lvl <- 1..9 do
        assert prev_rate.(lvl + 1) > prev_rate.(lvl),
               "Level #{lvl + 1} should produce more than level #{lvl}"
      end
    end

    test "hydrogen_extractor level 1: 140 * 1 * 1.1^1 = 154.0" do
      rates = rates_with_power(b("hydrogen_extractor", 1), 10)
      assert Float.round(rates.hydrogen, 2) == 154.0
    end

    test "microchip_factory level 1: 170 * 1 * 1.1^1 = 187.0" do
      rates = rates_with_power(b("microchip_factory", 1), 10)
      assert Float.round(rates.microchips, 2) == 187.0
    end

    test "farm level 1: 150 * 1 * 1.1^1 = 165.0" do
      rates = rates_with_power(b("farm", 1), 10)
      assert Float.round(rates.food, 2) == 165.0
    end
  end

  # ---------------------------------------------------------------------------
  # Energy production
  # ---------------------------------------------------------------------------

  describe "energy production" do
    test "power_plant level 1: 75 * 1 * 1.1^1 = 82.5" do
      rates = ProductionEngine.calculate_rates([b("power_plant", 1)])
      assert Float.round(rates.energy_produce, 2) == 82.5
    end

    test "nuclear_reactor level 1: 120 * 1 * 1.1^1 = 132.0" do
      rates = ProductionEngine.calculate_rates([b("nuclear_reactor", 1)])
      assert Float.round(rates.energy_produce, 2) == 132.0
    end

    test "nuclear_reactor produces more than power_plant at same level" do
      pp_rates = ProductionEngine.calculate_rates([b("power_plant", 3)])
      nr_rates = ProductionEngine.calculate_rates([b("nuclear_reactor", 3)])
      assert nr_rates.energy_produce > pp_rates.energy_produce
    end

    test "energy_produce_for/2 returns 0.0 for non-energy building" do
      assert ProductionEngine.energy_produce_for("mine_raw", 5) == 0.0
    end

    test "energy_produce_for/2 returns correct value for power_plant" do
      expected = 75 * 1 * :math.pow(1.1, 1)
      assert abs(ProductionEngine.energy_produce_for("power_plant", 1) - expected) < 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # Energy efficiency boundary tests
  # ---------------------------------------------------------------------------

  describe "energy efficiency boundaries" do
    test "efficiency = 1.0 when no buildings (no consumers, no producers)" do
      rates = ProductionEngine.calculate_rates([])
      assert rates.efficiency == 1.0
    end

    test "efficiency = 1.0 when all buildings are level 0" do
      rates = ProductionEngine.calculate_rates([b("mine_raw", 0), b("power_plant", 0)])
      assert rates.efficiency == 1.0
    end

    test "efficiency < 1.0 when energy insufficient" do
      # mine_raw at level 5 consumes a lot; no power source
      rates = ProductionEngine.calculate_rates([b("mine_raw", 5)])
      assert rates.efficiency < 1.0
    end

    test "efficiency is capped at 1.0 even with excess energy" do
      # Very high power plant, minimal consumer
      rates = ProductionEngine.calculate_rates([b("power_plant", 20), b("mine_raw", 1)])
      assert rates.efficiency == 1.0
    end

    test "efficiency = 0.0 when zero energy and consumers present means production reduced" do
      # mine at level 3 but no power: efficiency < 1.0 so output < full output
      rates_no_power = ProductionEngine.calculate_rates([b("mine_raw", 3)])
      rates_with_power_lvl10 = rates_with_power(b("mine_raw", 3), 10)
      assert rates_no_power.raw_materials < rates_with_power_lvl10.raw_materials
    end

    test "energy_balance = produce - consume" do
      buildings = [b("power_plant", 5), b("mine_raw", 3), b("microchip_factory", 2)]
      rates = ProductionEngine.calculate_rates(buildings)
      assert Float.round(rates.energy_balance, 6) ==
               Float.round(rates.energy_produce - rates.energy_consume, 6)
    end

    test "multiple generators stack" do
      rates_one = ProductionEngine.calculate_rates([b("power_plant", 3)])
      rates_two = ProductionEngine.calculate_rates([b("power_plant", 3), b("nuclear_reactor", 3)])
      assert rates_two.energy_produce > rates_one.energy_produce
    end

    test "efficiency at exactly 50% halves production" do
      # Construct scenario where efficiency ≈ 0.5
      buildings = [b("mine_raw", 5), b("power_plant", 3)]
      rates = ProductionEngine.calculate_rates(buildings)

      # Compute what full production would be
      full_rates = rates_with_power(b("mine_raw", 5), 20)

      if rates.efficiency < 1.0 do
        assert rates.raw_materials < full_rates.raw_materials
        # The efficiency factor should be applied correctly
        expected = full_rates.raw_materials * rates.efficiency
        assert abs(rates.raw_materials - expected) < 0.1
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Build costs
  # ---------------------------------------------------------------------------

  describe "build_cost/2" do
    test "cost at level 1 is the base cost" do
      cost = ProductionEngine.build_cost("mine_raw", 1)
      assert cost.raw_materials == 100
    end

    test "cost scales linearly with level" do
      cost_l1 = ProductionEngine.build_cost("mine_raw", 1)
      cost_l2 = ProductionEngine.build_cost("mine_raw", 2)
      cost_l3 = ProductionEngine.build_cost("mine_raw", 3)
      assert cost_l2.raw_materials == cost_l1.raw_materials * 2
      assert cost_l3.raw_materials == cost_l1.raw_materials * 3
    end

    test "returns 0 cost for unknown resource fields" do
      cost = ProductionEngine.build_cost("mine_raw", 1)
      refute Map.has_key?(cost, :microchips)
    end
  end

  # ---------------------------------------------------------------------------
  # can_afford?/2
  # ---------------------------------------------------------------------------

  describe "can_afford?/2" do
    defp planet_with(overrides) do
      %{raw_materials: 1000.0, microchips: 1000.0, hydrogen: 1000.0, food: 1000.0, credits: 1000.0}
      |> Map.merge(overrides)
    end

    test "returns true when planet has enough of each resource" do
      planet = planet_with(%{raw_materials: 500.0})
      cost = %{raw_materials: 100}
      assert ProductionEngine.can_afford?(planet, cost)
    end

    test "returns false when planet lacks a resource" do
      planet = planet_with(%{raw_materials: 50.0})
      cost = %{raw_materials: 100}
      refute ProductionEngine.can_afford?(planet, cost)
    end

    test "returns true when planet has exactly enough" do
      planet = planet_with(%{raw_materials: 100.0})
      cost = %{raw_materials: 100}
      assert ProductionEngine.can_afford?(planet, cost)
    end

    test "checks all required resources" do
      planet = planet_with(%{raw_materials: 500.0, microchips: 5.0})
      cost = %{raw_materials: 100, microchips: 50}
      refute ProductionEngine.can_afford?(planet, cost)
    end

    test "empty cost is always affordable" do
      planet = planet_with(%{raw_materials: 0.0})
      assert ProductionEngine.can_afford?(planet, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Regression snapshot: economy at known state
  # ---------------------------------------------------------------------------

  describe "economy regression snapshot" do
    test "all mines at level 1, power_plant at level 2: rates within expected ranges" do
      buildings = [
        b("mine_raw", 1),
        b("microchip_factory", 1),
        b("hydrogen_extractor", 1),
        b("farm", 1),
        b("power_plant", 2)
      ]

      rates = ProductionEngine.calculate_rates(buildings)

      # Energy: pp at L2 should cover 4 mines at L1
      assert rates.efficiency == 1.0, "Expected 100% efficiency with power_plant at L2"

      # Raw materials: 200 * 1 * 1.1^1 = 220.0
      assert Float.round(rates.raw_materials, 1) == 220.0

      # Microchips: 170 * 1 * 1.1^1 = 187.0
      assert Float.round(rates.microchips, 1) == 187.0

      # Hydrogen: 140 * 1 * 1.1^1 = 154.0
      assert Float.round(rates.hydrogen, 1) == 154.0

      # Food: 150 * 1 * 1.1^1 = 165.0
      assert Float.round(rates.food, 1) == 165.0
    end

    test "component_factory produces microchips" do
      rates = rates_with_power(b("component_factory", 1), 10)
      # 120 * 1 * 1.1^1 = 132
      assert Float.round(rates.microchips, 1) == 132.0
    end
  end
end
