defmodule ShardexDemo.Tenants do
  @moduledoc """
  Per-tenant data (contacts), stored in the shard databases via
  `ShardexDemo.ShardRepo`.

  Every function is scoped to a tenant slug and routes through the shardex
  instance. There are two complementary ways to run a shard query; this context
  shows both:

    * `Shards.run(slug, fn repo -> ... end)` — shardex binds the dynamic repo to
      the tenant's shard for the duration of the fun and restores it after. Use
      this for one-off work or background processes.
    * Rely on the ambient binding — when the LiveView process (or the request
      process) has already been bound to the shard (see `ShardexDemoWeb.ShardScope`
      and `ShardexDemoWeb.Plugs.TenantFromSubdomain`), plain `ShardRepo.*` calls
      hit the right shard. These functions still take the slug so they can scope
      rows *within* the shard by `org_slug`.

  Because a shard holds many tenants, every query filters by `org_slug`.
  """
  import Ecto.Query

  alias ShardexDemo.ShardRepo
  alias ShardexDemo.Shards
  alias ShardexDemo.Tenants.Contact

  @doc """
  Lists a tenant's contacts, routing to the tenant's shard explicitly via
  `Shards.run/2`.
  """
  @spec list_contacts(String.t()) :: {:ok, [Contact.t()]} | {:error, term()}
  def list_contacts(slug) when is_binary(slug) do
    Shards.run(slug, fn repo ->
      repo.all(scoped(slug))
    end)
  end

  @doc """
  Lists a tenant's contacts assuming the current process is **already** bound to
  the tenant's shard (e.g. inside a LiveView mounted through `ShardScope`).
  Still scopes by `org_slug` within the shard.
  """
  @spec list_contacts_bound(String.t()) :: [Contact.t()]
  def list_contacts_bound(slug) when is_binary(slug) do
    ShardRepo.all(scoped(slug))
  end

  @doc "Creates a contact for a tenant, routing to its shard via `Shards.run/2`."
  @spec create_contact(String.t(), map()) ::
          {:ok, Contact.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_contact(slug, attrs) when is_binary(slug) do
    Shards.run(slug, fn repo ->
      %Contact{org_slug: slug}
      |> Contact.changeset(attrs)
      |> repo.insert()
    end)
    |> unwrap_run()
  end

  @doc "A changeset for a contact form."
  @spec change_contact(Contact.t(), map()) :: Ecto.Changeset.t()
  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end

  @doc """
  Counts contacts per shard across **all** shards in one routing pass, using
  `run_batch/4`. Handy for an operational overview that doesn't belong to any
  single tenant. Returns `%{shard_atom => count}`.
  """
  @spec count_by_shard([String.t()]) :: %{atom() => non_neg_integer()}
  def count_by_shard(slugs) when is_list(slugs) do
    {:ok, results, _errors} =
      Shards.run_batch(slugs, & &1, fn repo, shard_slugs ->
        repo.aggregate(from(c in Contact, where: c.org_slug in ^shard_slugs), :count)
      end)

    results
  end

  defp scoped(slug),
    do: from(c in Contact, where: c.org_slug == ^slug, order_by: [desc: c.inserted_at])

  # Shards.run returns {:ok, result}; here result is itself an insert's
  # {:ok, _} | {:error, changeset}. Flatten so callers see one tuple. A routing
  # failure ({:error, reason}) passes straight through.
  defp unwrap_run({:ok, inner}), do: inner
  defp unwrap_run({:error, _reason} = err), do: err
end
