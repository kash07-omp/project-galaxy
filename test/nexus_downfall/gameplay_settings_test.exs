defmodule NexusDownfall.GameplaySettingsTest do
  use ExUnit.Case, async: true

  alias NexusDownfall.GameplaySettings

  test "combat_settings falls back when combat section is missing" do
    key = {GameplaySettings, :settings}
    original = :persistent_term.get(key, :undefined)

    :persistent_term.put(key, %{"fleet_travel" => %{}, "planet" => %{}, "colonization" => %{}})

    assert %{"max_rounds" => max_rounds} = GameplaySettings.combat_settings()
    assert max_rounds == 6

    on_exit(fn ->
      case original do
        :undefined -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end
    end)
  end
end
