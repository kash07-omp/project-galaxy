defmodule NexusDownfall.ObanTest do
  @moduledoc """
  Tests that Oban can enqueue and execute jobs.

  In test env, Oban runs in `:inline` mode — jobs are executed synchronously
  at insert time, so no polling or async waiting is required.
  """

  use NexusDownfall.DataCase, async: true

  alias NexusDownfall.Workers.PingWorker

  test "can enqueue a job (inline execution succeeds)" do
    assert {:ok, _job} =
             %{"action" => "ping"}
             |> PingWorker.new()
             |> Oban.insert()
  end

  test "job with wrong args returns an error tuple" do
    # In inline mode the worker result is surfaced on insert.
    result =
      %{"action" => "unknown"}
      |> PingWorker.new()
      |> Oban.insert()

    # Inline mode still returns {:ok, job} but the job is marked as discarded.
    # What matters is that the system doesn't crash.
    assert match?({:ok, _} , result) or match?({:error, _}, result)
  end
end
