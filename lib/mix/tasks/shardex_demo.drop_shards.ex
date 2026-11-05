defmodule Mix.Tasks.ShardexDemo.DropShards do
  @shortdoc "Drops the shard databases"
  @moduledoc """
  Drops each shard database declared in the `ShardexDemo.Shards` config (the
  counterpart to `mix shardex_demo.setup_shards`). Used by `mix ecto.reset`.

  Idempotent: databases that are already gone are skipped.

      mix shardex_demo.drop_shards
  """
  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    quiet? = "--quiet" in args
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)

    for opts <- ShardexDemo.ShardConfig.storage_opts() do
      database = opts[:database]

      case Ecto.Adapters.Postgres.storage_down(opts) do
        :ok -> log(quiet?, "dropped #{database}")
        {:error, :already_down} -> log(quiet?, "absent  #{database}")
        {:error, reason} -> Mix.raise("storage_down failed for #{database}: #{inspect(reason)}")
      end
    end
  end

  defp log(true, _msg), do: :ok
  defp log(false, msg), do: Mix.shell().info(msg)
end
