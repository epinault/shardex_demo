defmodule ShardexDemo.Shards do
  @moduledoc """
  The shardex **instance** for this app.

  `use Shardex` generates the routing API on this module:

    * `lookup/1`   – `{:ok, %Shardex.Shard{}}` for a key
    * `ref/2`      – the pool ref; in dynamic Ecto mode, the dynamic repo name
    * `run/2`      – runs a fun against the routed pool, binding (and restoring)
                     `ShardexDemo.ShardRepo`'s dynamic repo around it
    * `run_batch/4`, `group/2` – batch routing
    * `shards/0`   – all shards (used by the migration task)
    * `invalidate/1` – drop a cached route after a reassignment

  The shard topology and routing strategy are configured per environment under
  `config :shardex_demo, ShardexDemo.Shards` (see `config/dev.exs`,
  `config/test.exs`, `config/runtime.exs`). The strategy is
  `ShardexDemo.OrgDirectory` wrapped in `Shardex.Strategy.Cached` — i.e. tenant
  → shard assignments come from the `organizations` catalog table.

  Keys are **organization slugs** (strings) everywhere: the subdomain gives us a
  slug with no prior lookup, so we route by slug consistently.
  """
  use Shardex, otp_app: :shardex_demo
end
