defmodule ShardexDemo.Catalog do
  @moduledoc """
  The tenant directory, backed by `ShardexDemo.CatalogRepo` (the unsharded
  catalog database).

  This context owns organizations and — crucially — their shard assignments.
  Creating an org picks a shard (via `ShardexDemo.ShardAssignment`, unless one
  is supplied), and whenever an assignment changes we tell shardex to drop its
  cached route with `ShardexDemo.Shards.invalidate/1`.
  """
  import Ecto.Query

  alias ShardexDemo.Catalog.Organization
  alias ShardexDemo.CatalogRepo
  alias ShardexDemo.ShardAssignment
  alias ShardexDemo.Shards

  @doc "Lists all organizations, newest first."
  @spec list_organizations() :: [Organization.t()]
  def list_organizations do
    Organization
    |> order_by([o], desc: o.inserted_at)
    |> CatalogRepo.all()
  end

  @doc "Fetches an organization by id, raising if missing."
  @spec get_organization!(term()) :: Organization.t()
  def get_organization!(id), do: CatalogRepo.get!(Organization, id)

  @doc "Fetches an organization by slug."
  @spec fetch_org_by_slug(String.t()) :: {:ok, Organization.t()} | {:error, :not_found}
  def fetch_org_by_slug(slug) when is_binary(slug) do
    case CatalogRepo.get_by(Organization, slug: slug) do
      nil -> {:error, :not_found}
      org -> {:ok, org}
    end
  end

  @doc "Counts organizations grouped by shard name, e.g. `%{\"shard_1\" => 3}`."
  @spec counts_by_shard() :: %{String.t() => non_neg_integer()}
  def counts_by_shard do
    Organization
    |> group_by([o], o.shard_name)
    |> select([o], {o.shard_name, count(o.id)})
    |> CatalogRepo.all()
    |> Map.new()
  end

  @doc """
  Creates an organization.

  If `attrs` has no `shard_name` (or it is blank), one is chosen automatically
  by `ShardexDemo.ShardAssignment.pick_shard/0`.
  """
  @spec create_organization(map()) :: {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def create_organization(attrs \\ %{}) do
    attrs = put_shard_if_missing(attrs)

    %Organization{}
    |> Organization.changeset(attrs)
    |> CatalogRepo.insert()
  end

  @doc """
  Reassigns an organization to a different shard.

  After the change commits, `Shards.invalidate/1` drops the cached route so the
  next request resolves the new shard. Note this does **not** move existing
  rows — routing is by database connection, so data already written to the old
  shard stays there. (The demo treats assignment as create-time in practice.)
  """
  @spec reassign_shard(Organization.t(), String.t()) ::
          {:ok, Organization.t()} | {:error, Ecto.Changeset.t()}
  def reassign_shard(%Organization{} = org, shard_name) do
    result =
      org
      |> Organization.changeset(%{shard_name: shard_name})
      |> CatalogRepo.update()

    with {:ok, updated} <- result do
      # Invalidate AFTER the commit so a concurrent lookup can't re-cache the old
      # assignment from an uncommitted read.
      Shards.invalidate(updated.slug)
      {:ok, updated}
    end
  end

  @doc "A changeset for an organization form."
  @spec change_organization(Organization.t(), map()) :: Ecto.Changeset.t()
  def change_organization(%Organization{} = org, attrs \\ %{}) do
    Organization.changeset(org, attrs)
  end

  defp put_shard_if_missing(attrs) do
    case blank_shard(attrs) do
      true -> Map.put(attrs, shard_key(attrs), ShardAssignment.pick_shard())
      false -> attrs
    end
  end

  defp blank_shard(attrs) do
    value = Map.get(attrs, "shard_name") || Map.get(attrs, :shard_name)
    value in [nil, ""]
  end

  # Preserve the key style (string vs atom) the caller used.
  defp shard_key(attrs) do
    if Map.has_key?(attrs, :shard_name) or not Map.has_key?(attrs, "shard_name"),
      do: :shard_name,
      else: "shard_name"
  end
end
