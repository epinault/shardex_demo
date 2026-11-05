defmodule Mix.Tasks.ShardexDemo.SetupShards do
  @shortdoc "Creates the shard databases"
  @moduledoc """
  Creates each shard database declared in the `ShardexDemo.Shards` config.

  The shard repo is in dynamic mode and is intentionally not part of
  `:ecto_repos`, so `mix ecto.create` does not know about these databases. This
  task reads the shard list straight from config (so it does **not** start the
  app, and therefore the shard pools, before the databases exist) and runs
  `Ecto.Adapters.Postgres.storage_up/1` for each.

  Idempotent: databases that already exist are left alone.

      mix shardex_demo.setup_shards
      mix shardex_demo.setup_shards --quiet
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

      case Ecto.Adapters.Postgres.storage_up(opts) do
        :ok -> log(quiet?, "created #{database}")
        {:error, :already_up} -> log(quiet?, "exists  #{database}")
        {:error, reason} -> Mix.raise("storage_up failed for #{database}: #{inspect(reason)}")
      end
    end
  end

  defp log(true, _msg), do: :ok
  defp log(false, msg), do: Mix.shell().info(msg)
end
