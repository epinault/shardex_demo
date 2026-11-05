defmodule ShardexDemo.ShardAssignment do
  @moduledoc """
  Custom logic for **assigning** a new tenant to a shard.

  This is one of the two places you wire your own policy into the demo (the
  other is `ShardexDemo.OrgDirectory`, which *resolves* an existing assignment
  for routing). Assignment answers a different question: when a brand-new
  organization signs up, which shard should hold its data?

  The policy here is "least loaded" — pick the configured shard that currently
  has the fewest organizations in the catalog, breaking ties by shard order.
  Swap this for hashing, a region map, a capacity table, manual placement, or
  whatever your product needs; nothing else in the app has to change.
  """
  import Ecto.Query

  alias ShardexDemo.CatalogRepo
  alias ShardexDemo.Catalog.Organization
  alias ShardexDemo.Tenancy

  @doc """
  Picks the least-loaded shard name (a string like `"shard_1"`).

  Counts organizations per shard in the catalog and returns the shard with the
  fewest, so tenants spread evenly as they sign up.
  """
  @spec pick_shard() :: String.t()
  def pick_shard do
    counts =
      Organization
      |> group_by([o], o.shard_name)
      |> select([o], {o.shard_name, count(o.id)})
      |> CatalogRepo.all()
      |> Map.new()

    Tenancy.shard_name_strings()
    |> Enum.min_by(&Map.get(counts, &1, 0))
  end
end
