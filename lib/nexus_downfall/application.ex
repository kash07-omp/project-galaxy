defmodule NexusDownfall.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NexusDownfallWeb.Telemetry,
      NexusDownfall.Repo,
      {DNSCluster, query: Application.get_env(:nexus_downfall, :dns_cluster_query, :ignore)},
      {Phoenix.PubSub, name: NexusDownfall.PubSub},
      {Finch, name: NexusDownfall.Finch},
      {Oban, Application.fetch_env!(:nexus_downfall, Oban)},
      NexusDownfallWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NexusDownfall.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NexusDownfallWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
