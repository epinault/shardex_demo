defmodule ShardexDemo.ShardConfig do
  @moduledoc """
  Reads the shard topology from application config, without starting the shard
  pools. Used by the `setup_shards` / `drop_shards` mix tasks to create and drop
  the shard databases before the app (and its pools) boot.
  """

  @doc """
  Returns a list of Postgres connection option keyword lists, one per shard,
  suitable for `Ecto.Adapters.Postgres.storage_up/1` and `storage_down/1`.

  Each entry is the base `ShardexDemo.ShardRepo` config (credentials, host)
  merged with that shard's `config:` (the `database:`).
  """
  @spec storage_opts() :: [keyword()]
  def storage_opts do
    base = Application.get_env(:shardex_demo, ShardexDemo.ShardRepo, [])

    for {_name, spec} <- configured_shards() do
      Keyword.merge(base, shard_config(spec))
    end
  end

  defp configured_shards do
    :shardex_demo
    |> Application.get_env(ShardexDemo.Shards, [])
    |> Keyword.get(:shards, [])
  end

  # Single-role spec: {Shardex.Adapter.Ecto, repo: ..., config: [...]}
  defp shard_config({Shardex.Adapter.Ecto, opts}) when is_list(opts),
    do: Keyword.get(opts, :config, [])

  # Multi-role spec: [primary: {Shardex.Adapter.Ecto, ...}, replica: {...}].
  # The databases are the same across roles; use the primary.
  defp shard_config(roles) when is_list(roles) do
    case Keyword.get(roles, :primary) do
      {Shardex.Adapter.Ecto, opts} -> Keyword.get(opts, :config, [])
      _ -> []
    end
  end
end
