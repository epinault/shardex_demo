defmodule ShardexDemo.ShardRepo do
  @moduledoc """
  The **shard** repo: one `Ecto.Repo` module that fronts *many* Postgres
  databases, one per shard. This is shardex's "dynamic mode".

  Important: this repo is **not** in `:ecto_repos` and is **not** started in the
  application supervision tree. `ShardexDemo.Shards` starts it once per shard
  pool, each under its own dynamic name (e.g. `ShardexDemo.Shards.shard_1.primary`)
  with the shard's `database:` merged over the base config below.

  At request time, `ShardRepo.put_dynamic_repo(name)` points this module at a
  specific shard's pool for the current process, and every `ShardRepo.*` call
  then runs against that shard's database. `ShardexDemo.Shards.run/2` does this
  for you (and restores the previous binding afterwards).

  The base application config for this repo carries connection credentials but
  **no `:database`** — the database name is supplied per shard in the
  `ShardexDemo.Shards` config.
  """
  use Ecto.Repo,
    otp_app: :shardex_demo,
    adapter: Ecto.Adapters.Postgres
end
