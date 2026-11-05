defmodule ShardexDemo.OrgDirectory do
  @moduledoc """
  The custom shardex **strategy**: resolve a tenant slug to its shard by reading
  the `organizations` table in the catalog.

  This is the "wire your own logic" hook. shardex calls `route_many/2` with a
  batch of keys (organization slugs) and the routing context; we look the slugs
  up in the catalog and return each one's shard. In config this is wrapped in
  `Shardex.Strategy.Cached`, so the database is only hit on a cache miss:

      strategy: {Shardex.Strategy.Cached, inner: ShardexDemo.OrgDirectory, ttl: ...}

  Contract notes:

    * Keys are organization **slugs** (strings).
    * `ctx.shards` is the list of configured shard atoms, e.g. `[:shard_1, :shard_2]`.
    * Return `%{key => {:ok, shard_atom} | {:error, reason}}`. A slug with no row
      is `{:error, :not_found}`; a slug whose stored `shard_name` isn't a known
      shard is `{:error, {:unknown_shard, name}}`.
    * We only ever turn a stored shard name into an atom with
      `String.to_existing_atom/1`, and only after checking it against
      `ctx.shards` — never `String.to_atom/1` on data.
  """
  @behaviour Shardex.Strategy

  import Ecto.Query

  alias ShardexDemo.Catalog.Organization
  alias ShardexDemo.CatalogRepo

  @impl Shardex.Strategy
  def route_many(keys, ctx) do
    keys = Enum.uniq(keys)
    valid = MapSet.new(ctx.shards, &Atom.to_string/1)

    assignments =
      from(o in Organization, where: o.slug in ^keys, select: {o.slug, o.shard_name})
      |> CatalogRepo.all()
      |> Map.new()

    Map.new(keys, fn slug ->
      {slug, resolve(Map.get(assignments, slug), valid)}
    end)
  end

  defp resolve(nil, _valid), do: {:error, :not_found}

  defp resolve(shard_name, valid) when is_binary(shard_name) do
    if MapSet.member?(valid, shard_name) do
      {:ok, String.to_existing_atom(shard_name)}
    else
      {:error, {:unknown_shard, shard_name}}
    end
  end
end
