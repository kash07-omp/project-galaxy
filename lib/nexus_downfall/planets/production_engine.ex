defmodule NexusDownfall.Planets.ProductionEngine do
  @moduledoc """
  Pure-functional production engine for planetary economy.

  All formulas are parametric and concentrated here for easy balancing.
  No database calls — takes building list + planet state, returns rates/deltas.

  ## Resource units
  All rates are **per hour** at the given building level.
  A tick applies the rate proportionally to elapsed seconds.

  ## Energy mechanics
  `power_plant` produces energy. All other active buildings consume energy.
  If total production < total consumption, an `efficiency` factor (0..1) is
  applied to ALL resource outputs. Buildings with level 0 are ignored.
  """

  # ---------------------------------------------------------------------------
  # Building definitions
  # ---------------------------------------------------------------------------
  # Each entry: {resource_produced, per_hour_per_level, energy_consumed_per_level}
  # energy_balance is handled separately via :energy_produce key

  @defs %{
    "command_center"     => %{energy_consume: 2},
    "mine_raw"           => %{raw_materials: 20, energy_consume: 5},
    "microchip_factory"  => %{microchips: 15, energy_consume: 7},
    "hydrogen_extractor" => %{hydrogen: 15, energy_consume: 6},
    "farm"               => %{food: 20, energy_consume: 3},
    "power_plant"        => %{energy_produce: 30},
    "residential"        => %{population: 10, energy_consume: 2},
    "laboratory"         => %{energy_consume: 8},
    "spaceport"          => %{energy_consume: 10}
  }

  # ---------------------------------------------------------------------------
  # Build costs and times
  # ---------------------------------------------------------------------------
  # Cost to go from level (N-1) → N is: base_cost * N (linear scaling).
  # build_time_secs is also * N.

  @build_costs %{
    "command_center"     => %{raw_materials: 200, microchips: 80},
    "mine_raw"           => %{raw_materials: 100},
    "microchip_factory"  => %{raw_materials: 130, microchips: 40},
    "hydrogen_extractor" => %{raw_materials: 120},
    "farm"               => %{raw_materials: 80, food: 20},
    "power_plant"        => %{raw_materials: 160, microchips: 30},
    "residential"        => %{raw_materials: 100, food: 50},
    "laboratory"         => %{raw_materials: 220, microchips: 120},
    "spaceport"          => %{raw_materials: 350, microchips: 180}
  }

  # Base seconds at level 1. Scales linearly with target level.
  @build_time_base %{
    "command_center"     => 120,
    "mine_raw"           => 60,
    "microchip_factory"  => 90,
    "hydrogen_extractor" => 75,
    "farm"               => 60,
    "power_plant"        => 100,
    "residential"        => 75,
    "laboratory"         => 150,
    "spaceport"          => 200
  }

  @max_offline_hours 24

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns hourly production rates for a list of buildings, accounting for
  energy efficiency.

  Returns a map:
    %{raw_materials: f, microchips: f, hydrogen: f, food: f,
      population: i, energy_balance: f, efficiency: f}
  """
  def calculate_rates(buildings) do
    active = Enum.filter(buildings, &(&1.level > 0))

    energy_produce = sum_for(active, :energy_produce)
    energy_consume = sum_for(active, :energy_consume)
    efficiency = if energy_consume == 0, do: 1.0, else: min(1.0, energy_produce / energy_consume)

    %{
      raw_materials:  sum_for(active, :raw_materials) * efficiency,
      microchips:     sum_for(active, :microchips) * efficiency,
      hydrogen:       sum_for(active, :hydrogen) * efficiency,
      food:           sum_for(active, :food) * efficiency,
      population:     round(sum_for(active, :population) * efficiency),
      energy_balance: energy_produce - energy_consume,
      efficiency:     Float.round(efficiency, 3)
    }
  end

  @doc """
  Applies accumulated production since `planet.last_tick_at` to planet
  resource fields. Returns an attrs map suitable for `Ecto.Changeset.cast/3`.

  Caps offline accumulation at `@max_offline_hours` hours.
  """
  def apply_tick(planet, buildings) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    elapsed_secs = DateTime.diff(now, planet.last_tick_at, :second)
    elapsed_hours = min(elapsed_secs / 3600.0, @max_offline_hours)

    rates = calculate_rates(buildings)

    %{
      raw_materials: planet.raw_materials + rates.raw_materials * elapsed_hours,
      microchips:    planet.microchips    + rates.microchips    * elapsed_hours,
      hydrogen:      planet.hydrogen      + rates.hydrogen      * elapsed_hours,
      food:          planet.food          + rates.food          * elapsed_hours,
      credits:       planet.credits,
      population:    planet.population    + round(rates.population * elapsed_hours),
      last_tick_at:  now
    }
  end

  @doc """
  Returns build cost map for upgrading a building to `next_level`.
  """
  def build_cost(type, next_level) do
    base = Map.get(@build_costs, type, %{})
    Map.new(base, fn {k, v} -> {k, round(v * next_level)} end)
  end

  @doc """
  Returns build time in seconds for upgrading a building to `next_level`.
  """
  def build_time_seconds(type, next_level) do
    round(Map.get(@build_time_base, type, 60) * next_level)
  end

  @doc """
  Returns whether the planet has sufficient resources to cover `cost` map.
  """
  def can_afford?(planet, cost) do
    Enum.all?(cost, fn {resource, amount} ->
      Map.get(planet, resource, 0) >= amount
    end)
  end

  @doc """
  Deducts `cost` from planet resource fields.
  Returns an attrs map for `Ecto.Changeset.cast/3`.
  """
  def deduct_cost(planet, cost) do
    Map.new(cost, fn {resource, amount} ->
      {resource, Map.get(planet, resource, 0) - amount}
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp sum_for(buildings, key) do
    Enum.reduce(buildings, 0.0, fn b, acc ->
      def_map = Map.get(@defs, b.type, %{})
      rate = Map.get(def_map, key, 0)
      acc + rate * b.level
    end)
  end
end
