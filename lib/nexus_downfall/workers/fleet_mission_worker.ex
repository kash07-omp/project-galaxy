defmodule NexusDownfall.Workers.FleetMissionWorker do
  @moduledoc "Processes fleet mission phase transitions."

  use Oban.Worker, queue: :missions, max_attempts: 5

  alias NexusDownfall.Fleets

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"mission_id" => mission_id, "action" => action}}) do
    Fleets.process_mission_transition(mission_id, action)
  end
end
