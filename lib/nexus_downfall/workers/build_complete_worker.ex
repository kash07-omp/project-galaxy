defmodule NexusDownfall.Workers.BuildCompleteWorker do
  @moduledoc """
  Oban worker that finalises a building upgrade when its timer expires.

  Scheduled by `Planets.start_construction/2` with a delay equal to
  the build time. On execution it increments the building's level and
  clears the in-progress flag.
  """

  use Oban.Worker, queue: :construction, max_attempts: 3

  alias NexusDownfall.Repo
  alias NexusDownfall.Planets.Building
  import Ecto.Query
  import Ecto.Changeset

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"building_id" => building_id}}) do
    Repo.transaction(fn ->
      building =
        Repo.one(from b in Building, where: b.id == ^building_id, lock: "FOR UPDATE")

      cond do
        is_nil(building) ->
          :ok

        is_nil(building.construction_finish_at) ->
          :ok

        true ->
          building
          |> change(%{
            level: building.level + 1,
            construction_finish_at: nil,
            oban_job_id: nil
          })
          |> Repo.update()
          |> case do
            {:ok, updated} ->
              :telemetry.execute(
                [:nexus_downfall, :planets, :construction_completed],
                %{count: 1},
                %{planet_id: updated.planet_id, building_type: updated.type}
              )

              :ok

            {:error, changeset} ->
              Repo.rollback({:error, inspect(changeset.errors)})
          end
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> reason
    end
  end
end
