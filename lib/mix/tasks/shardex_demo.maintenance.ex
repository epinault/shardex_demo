defmodule Mix.Tasks.ShardexDemo.Maintenance do
  @shortdoc "Drain/stop/activate a shard on the running server (simulate maintenance)"
  @moduledoc """
  Flips a shard's maintenance state on the **running** server, so you can watch
  the subdomain plug return `503` for tenants on that shard and recover.

  shardex maintenance state is in-memory on the running instance, so this task
  does not start its own app — it connects to the server node and calls
  `ShardexDemo.Shards` there over Erlang RPC.

  ## Usage

      mix shardex_demo.maintenance <shard> <drain|stop|activate|status>

      mix shardex_demo.maintenance shard_1 drain      # stop routing, keep the pool
      mix shardex_demo.maintenance shard_1 stop        # stop routing and the pool
      mix shardex_demo.maintenance shard_1 activate    # back into rotation
      mix shardex_demo.maintenance shard_1 status      # :active | :drain | :stopped

  ## Reaching the server

  Start the server with a node name and cookie so this task can connect:

      SHARDEX_DEMO_PGPORT=5432 \\
        elixir --name shardex_demo@127.0.0.1 --cookie shardex_demo -S mix phx.server

  The task targets `shardex_demo@127.0.0.1` / cookie `shardex_demo` by default;
  override with `SHARDEX_DEMO_NODE` and `SHARDEX_DEMO_COOKIE`.

  Then, e.g., `curl -H "Host: acme.lvh.me" localhost:4000/contacts` returns 503
  while acme's shard is drained, and 200 again after `activate`.
  """
  use Mix.Task

  @actions ~w(drain stop activate status)

  @impl Mix.Task
  def run(args) do
    {shard, action} = parse_args(args)
    node = node_name()
    connect!(node)

    result =
      case action do
        "drain" -> rpc(node, :maintenance, [shard, :drain])
        "stop" -> rpc(node, :maintenance, [shard, :stop])
        "activate" -> rpc(node, :activate, [shard])
        "status" -> rpc(node, :status, [shard])
      end

    Mix.shell().info("#{action} #{shard} on #{node} -> #{inspect(result)}")
  end

  defp parse_args([shard, action]) when action in @actions do
    {to_shard(shard), action}
  end

  defp parse_args(_args) do
    Mix.raise("usage: mix shardex_demo.maintenance <shard> <#{Enum.join(@actions, "|")}>")
  end

  defp to_shard(shard) do
    known = ShardexDemo.Tenancy.shard_name_strings()

    if shard in known do
      String.to_existing_atom(shard)
    else
      Mix.raise("unknown shard #{inspect(shard)}; known shards: #{Enum.join(known, ", ")}")
    end
  end

  defp rpc(node, fun, extra_args) do
    case :rpc.call(node, ShardexDemo.Shards, fun, extra_args) do
      {:badrpc, reason} -> Mix.raise("RPC to #{node} failed: #{inspect(reason)}")
      other -> other
    end
  end

  defp node_name do
    System.get_env("SHARDEX_DEMO_NODE", "shardex_demo@127.0.0.1") |> String.to_atom()
  end

  defp connect!(node) do
    cookie = System.get_env("SHARDEX_DEMO_COOKIE", "shardex_demo") |> String.to_atom()
    self_name = :"shardex_demo_maint_#{System.system_time(:millisecond)}@127.0.0.1"

    case Node.start(self_name, :longnames) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      {:error, reason} ->
        Mix.raise("could not start distribution (is epmd running?): #{inspect(reason)}")
    end

    Node.set_cookie(cookie)

    unless Node.connect(node) do
      Mix.raise("""
      could not connect to #{node}.
      Start the server with a matching node name and cookie, e.g.

          elixir --name shardex_demo@127.0.0.1 --cookie shardex_demo -S mix phx.server
      """)
    end
  end
end
