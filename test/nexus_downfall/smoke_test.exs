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
    assert is_pid(Process.whereis(Oban))
  end

  test "PubSub process is running" do
    assert is_pid(Process.whereis(NexusDownfall.PubSub))
  end

  test "Endpoint process is running" do
    assert is_pid(Process.whereis(NexusDownfallWeb.Endpoint))
  end
end
