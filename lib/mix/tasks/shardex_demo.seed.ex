defmodule Mix.Tasks.ShardexDemo.Seed do
  @shortdoc "Seeds demo organizations and contacts"
  @moduledoc """
  Inserts demo organizations into the catalog and a few contacts into each
  tenant's shard (via `ShardexDemo.Seeds`). Requires the app to be started so
  the shard pools are available. Idempotent.

      mix shardex_demo.seed
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    ShardexDemo.Seeds.run()
  end
end
