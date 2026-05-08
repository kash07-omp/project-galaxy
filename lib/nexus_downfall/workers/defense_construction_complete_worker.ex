defmodule NexusDownfall.Workers.DefenseConstructionCompleteWorker do
  @moduledoc "Completes the active defense queue item and starts the next one, if any."

  use Oban.Worker, queue: :construction, max_attempts: 3

  alias NexusDownfall.Planets.Defenses

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"queue_item_id" => queue_item_id}}) do
    Defenses.complete_queue_item(queue_item_id)
  end
end
