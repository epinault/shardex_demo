defmodule ShardexDemo.ShardHelpers do
  @moduledoc """
  Test helpers for the (non-sandboxed) shard databases.

  The shard pools run under shardex's dynamic names and the connected-LiveView
  process is separate from the test process, so instead of the SQL sandbox we
  simply truncate shard tables. Call `reset_shards!/0` from the setup of any
  test that writes to a shard, and mark those tests `async: false`.
  """
  alias ShardexDemo.ShardRepo
  alias ShardexDemo.Shards

  @doc "Truncates every shard's `contacts` table."
  @spec reset_shards!() :: :ok
  def reset_shards! do
    previous = ShardRepo.get_dynamic_repo()

    try do
      for shard <- Shards.shards() do
        %{meta: %{dynamic_name: name}} = Map.fetch!(shard.roles, :primary)
        ShardRepo.put_dynamic_repo(name)
        ShardRepo.query!("TRUNCATE contacts RESTART IDENTITY")
      end
    after
      ShardRepo.put_dynamic_repo(previous)
    end

    :ok
  end
end
