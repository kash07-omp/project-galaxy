defmodule NexusDownfall.Workers.ShipConstructionCompleteWorker do
  @moduledoc "Completes the active shipyard queue item and starts the next one, if any."

  use Oban.Worker, queue: :construction, max_attempts: 3

  alias NexusDownfall.Fleets

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"queue_item_id" => queue_item_id}}) do
    Fleets.complete_queue_item(queue_item_id)
  end
end
