defmodule Mix.Tasks.ShardexDemo.MigrateShards do
  @shortdoc "Runs migrations against every shard database"
  @moduledoc """
  shardex does not run migrations. This task migrates every shard by enumerating
  `ShardexDemo.Shards.shards()` and running the migrations in
  `priv/shard_repo/migrations` against each shard's running pool, using
  `Ecto.Migrator`'s `:dynamic_repo` option so each shard keeps its own
  `schema_migrations` table.

  Requires the app (and thus the shard pools) to be started, which in turn
  requires the shard databases to already exist — run
  `mix shardex_demo.setup_shards` first (the `ecto.setup` / `test` aliases do).

      mix shardex_demo.migrate_shards
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    quiet? = "--quiet" in args
    path = Application.app_dir(:shardex_demo, "priv/shard_repo/migrations")

    for shard <- ShardexDemo.Shards.shards() do
      %{meta: %{repo: repo, dynamic_name: dynamic_name}} = Map.fetch!(shard.roles, :primary)
      unless quiet?, do: Mix.shell().info("migrating #{shard.name} (#{inspect(dynamic_name)})")
      Ecto.Migrator.run(repo, path, :up, all: true, dynamic_repo: dynamic_name)
    end
  end
end
