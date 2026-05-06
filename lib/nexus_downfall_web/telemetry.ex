defmodule NexusDownfallWeb.Telemetry do
  @moduledoc false

  use Supervisor

  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time", unit: {:native, :millisecond}),
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration", unit: {:native, :millisecond}),
      counter("phoenix.socket_connected.count"),
      summary("phoenix.channel_joined.duration", unit: {:native, :millisecond}),
      counter("phoenix.channel_joined.count"),

      # Ecto Metrics
      summary("nexus_downfall.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "Total query time"
      ),
      summary("nexus_downfall.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "Data decode time from DB"
      ),
      summary("nexus_downfall.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "SQL execution time"
      ),
      summary("nexus_downfall.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "Connection pool wait time"
      ),
      summary("nexus_downfall.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "Connection idle time before checkout"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    []
  end
end
