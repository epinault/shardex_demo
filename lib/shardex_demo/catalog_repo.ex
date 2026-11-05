defmodule ShardexDemo.CatalogRepo do
  @moduledoc """
  The **catalog** repo: a single, unsharded Postgres database.

  It holds the tenant directory — the `organizations` table that records, for
  each tenant, which shard its data lives on. `ShardexDemo.OrgDirectory` reads
  this repo to route requests, so the catalog is the source of truth for
  tenant → shard assignments.

  This is an ordinary `Ecto.Repo`. It is the only repo listed in `:ecto_repos`,
  so `mix ecto.create` / `mix ecto.migrate` operate on it. The per-tenant data
  lives in `ShardexDemo.ShardRepo` instead.
  """
  use Ecto.Repo,
    otp_app: :shardex_demo,
    adapter: Ecto.Adapters.Postgres
end
