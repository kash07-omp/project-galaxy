defmodule NexusDownfall.GameplaySettings do
  @moduledoc """
  Runtime gameplay settings loaded from `priv/settings/gameplay.json`.

  Values are cached in `:persistent_term` for low-overhead reads from hot paths
  (fleet dispatch and mission workers).
  """

  require Logger

  @persistent_key {__MODULE__, :settings}

  @defaults %{
    "colonization" => %{
      "base_seconds" => 600,
      "min_seconds" => 60
    },
    "planet" => %{
      "starter_resources" => %{
        "raw_materials" => 500,
        "microchips" => 500,
        "hydrogen" => 500,
        "food" => 500,
        "credits" => 1_000,
        "population" => 100
      },
      "starter_structures" => [
        %{"type" => "command_center", "level" => 1},
        %{"type" => "power_plant", "level" => 1}
      ]
    },
    "fleet_travel" => %{
      "launch_seconds" => 20,
      "landing_seconds" => 20,
      "seconds_per_hyperlink_hop" => 40,
      "seconds_per_orbit_step" => 6
    }
  }

  @spec load() :: map()
  def load do
    settings =
      settings_path()
      |> File.read()
      |> parse_settings_file()
      |> merge_with_defaults()
      |> sanitize()

    :persistent_term.put(@persistent_key, settings)
    settings
  end

  @spec reload() :: map()
  def reload, do: load()

  @spec all() :: map()
  def all do
    case :persistent_term.get(@persistent_key, :undefined) do
      :undefined -> load()
      settings -> settings
    end
  end

  @spec colonization_seconds(non_neg_integer()) :: non_neg_integer()
  def colonization_seconds(tech_reduction_seconds \\ 0) do
    colonization = Map.fetch!(all(), "colonization")
    base = Map.fetch!(colonization, "base_seconds")
    min_seconds = Map.fetch!(colonization, "min_seconds")

    max(base - max(tech_reduction_seconds, 0), min_seconds)
  end

  @spec planet_starter_resources() :: map()
  def planet_starter_resources do
    all()
    |> Map.fetch!("planet")
    |> Map.fetch!("starter_resources")
    |> atomize_map_keys()
  end

  @spec planet_starter_structures() :: list(%{type: String.t(), level: integer()})
  def planet_starter_structures do
    all()
    |> Map.fetch!("planet")
    |> Map.fetch!("starter_structures")
    |> Enum.map(fn item ->
      %{
        type: Map.get(item, "type", ""),
        level: sanitize_non_negative_int(Map.get(item, "level"), 0)
      }
    end)
    |> Enum.reject(&(&1.type == ""))
  end

  @spec travel_settings() :: map()
  def travel_settings do
    all() |> Map.fetch!("fleet_travel")
  end

  defp settings_path do
    default_path = Path.join([:code.priv_dir(:nexus_downfall), "settings", "gameplay.json"])
    Application.get_env(:nexus_downfall, :gameplay_settings_path, default_path)
  end

  defp parse_settings_file({:ok, contents}) do
    case Jason.decode(contents) do
      {:ok, settings} when is_map(settings) -> settings
      {:ok, _invalid} ->
        Logger.warning("Gameplay settings JSON must contain an object at root. Using defaults.")
        %{}

      {:error, reason} ->
        Logger.warning("Could not parse gameplay settings JSON: #{Exception.message(reason)}. Using defaults.")
        %{}
    end
  end

  defp parse_settings_file({:error, reason}) do
    Logger.warning("Could not read gameplay settings file (#{inspect(reason)}). Using defaults.")
    %{}
  end

  defp merge_with_defaults(settings), do: deep_merge(@defaults, settings)

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, lval, rval -> deep_merge(lval, rval) end)
  end

  defp deep_merge(_left, right), do: right

  defp sanitize(settings) do
    colonization = Map.get(settings, "colonization", %{})

    base_seconds = sanitize_non_negative_int(Map.get(colonization, "base_seconds"), 600)
    min_seconds = sanitize_non_negative_int(Map.get(colonization, "min_seconds"), 60)

    travel = Map.get(settings, "fleet_travel", %{})

    planet = Map.get(settings, "planet", %{})

    resources =
      planet
      |> Map.get("starter_resources", %{})
      |> sanitize_resources()

    structures =
      planet
      |> Map.get("starter_structures", [])
      |> sanitize_starter_structures()

    %{
      "colonization" => %{
        "base_seconds" => max(base_seconds, min_seconds),
        "min_seconds" => min_seconds
      },
      "planet" => %{
        "starter_resources" => resources,
        "starter_structures" => structures
      },
      "fleet_travel" => %{
        "launch_seconds" => sanitize_non_negative_int(Map.get(travel, "launch_seconds"), 20),
        "landing_seconds" => sanitize_non_negative_int(Map.get(travel, "landing_seconds"), 20),
        "seconds_per_hyperlink_hop" =>
          sanitize_non_negative_int(Map.get(travel, "seconds_per_hyperlink_hop"), 40),
        "seconds_per_orbit_step" =>
          sanitize_non_negative_int(Map.get(travel, "seconds_per_orbit_step"), 6)
      }
    }
  end

  defp sanitize_resources(resources) when is_map(resources) do
    %{
      "raw_materials" => sanitize_non_negative_int(Map.get(resources, "raw_materials"), 500),
      "microchips" => sanitize_non_negative_int(Map.get(resources, "microchips"), 500),
      "hydrogen" => sanitize_non_negative_int(Map.get(resources, "hydrogen"), 500),
      "food" => sanitize_non_negative_int(Map.get(resources, "food"), 500),
      "credits" => sanitize_non_negative_int(Map.get(resources, "credits"), 1_000),
      "population" => sanitize_non_negative_int(Map.get(resources, "population"), 100)
    }
  end

  defp sanitize_resources(_), do: sanitize_resources(%{})

  defp sanitize_starter_structures(value) when is_list(value) do
    value
    |> Enum.reduce([], fn
      %{"type" => type} = item, acc when is_binary(type) and type != "" ->
        [%{"type" => type, "level" => sanitize_non_negative_int(Map.get(item, "level"), 0)} | acc]

      _invalid, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp sanitize_starter_structures(_), do: []

  defp sanitize_non_negative_int(value, _default) when is_integer(value), do: max(value, 0)

  defp sanitize_non_negative_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> max(int, 0)
      _ -> default
    end
  end

  defp sanitize_non_negative_int(_value, default), do: default

  defp atomize_map_keys(map) do
    Map.new(map, fn {key, value} -> {String.to_existing_atom(key), value} end)
  rescue
    ArgumentError ->
      map
      |> Enum.reduce(%{}, fn
        {"raw_materials", value}, acc -> Map.put(acc, :raw_materials, value)
        {"microchips", value}, acc -> Map.put(acc, :microchips, value)
        {"hydrogen", value}, acc -> Map.put(acc, :hydrogen, value)
        {"food", value}, acc -> Map.put(acc, :food, value)
        {"credits", value}, acc -> Map.put(acc, :credits, value)
        {"population", value}, acc -> Map.put(acc, :population, value)
        {_other, _value}, acc -> acc
      end)
  end
end
