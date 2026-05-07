defmodule NexusDownfall.Workers.BuildCompleteWorker do
  @moduledoc """
  Oban worker that finalises a building upgrade when its timer expires.

  Scheduled by `Planets.start_construction/2` with a delay equal to
  the build time. On execution it increments the building's level and
  clears the in-progress flag.
  """

  use Oban.Worker, queue: :production, max_attempts: 3

  alias NexusDownfall.Repo
  alias NexusDownfall.Planets.Building
  import Ecto.Changeset

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"building_id" => building_id}}) do
    case Repo.get(Building, building_id) do
      nil ->
        # Building was deleted; treat as success so Oban doesn't retry
        :ok

      building ->
        building
        |> change(%{
          level: building.level + 1,
          construction_finish_at: nil,
          oban_job_id: nil
        })
        |> Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, inspect(changeset.errors)}
        end
    end
  end
end
