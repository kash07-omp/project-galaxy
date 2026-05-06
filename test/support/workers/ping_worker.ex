defmodule NexusDownfall.Workers.PingWorker do
  @moduledoc """
  Minimal test worker used only in smoke tests to verify Oban enqueue/execute.

  Not intended for production use.
  """

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "ping"}}) do
    :ok
  end

  def perform(%Oban.Job{args: args}) do
    {:error, "unexpected args: #{inspect(args)}"}
  end
end
