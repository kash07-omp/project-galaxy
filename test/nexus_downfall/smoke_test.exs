defmodule NexusDownfall.SmokeTest do
  @moduledoc """
  Smoke tests — verify that the application starts and basic subsystems are alive.

  These tests must stay fast and never require a real database or external services.
  """

  use ExUnit.Case, async: true

  test "application is started" do
    assert {:ok, _} = Application.ensure_all_started(:nexus_downfall)
  end

  test "Repo process is running" do
    assert is_pid(Process.whereis(NexusDownfall.Repo))
  end

  test "Oban process is running" do
    # In test env Oban is started but may register under a different name;
    # verify by checking it is in the application's supervision tree.
    assert {:ok, _} = Application.ensure_all_started(:nexus_downfall)
    oban_children =
      Supervisor.which_children(NexusDownfall.Supervisor)
      |> Enum.map(fn {id, _, _, _} -> id end)

    assert Enum.any?(oban_children, &match?(Oban, &1)) or is_pid(Process.whereis(Oban)),
           "Expected Oban to be supervised"
  end

  test "PubSub process is running" do
    assert is_pid(Process.whereis(NexusDownfall.PubSub))
  end

  test "Endpoint process is running" do
    assert is_pid(Process.whereis(NexusDownfallWeb.Endpoint))
  end
end
