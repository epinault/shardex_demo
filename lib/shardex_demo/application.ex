defmodule ShardexDemo.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShardexDemoWeb.Telemetry,
      # The catalog (tenant directory) must be up before the shard router,
      # because the routing strategy reads tenant → shard assignments from it.
      ShardexDemo.CatalogRepo,
      {DNSCluster, query: Application.get_env(:shardex_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ShardexDemo.PubSub},
      # The shardex instance. It starts one ShardexDemo.ShardRepo pool per shard
      # (dynamic mode), so ShardRepo itself is intentionally absent from this
      # tree and from :ecto_repos.
      ShardexDemo.Shards,
      # Start to serve requests, typically the last entry
      ShardexDemoWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShardexDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShardexDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
