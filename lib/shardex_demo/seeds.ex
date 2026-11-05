defmodule ShardexDemo.Seeds do
  @moduledoc """
  Idempotent demo data: a handful of organizations (spread across shards by the
  least-loaded assignment policy) and a few contacts each.

  Run via `mix shardex_demo.seed`. Safe to re-run: existing orgs are skipped,
  and contacts are only added to orgs that have none.
  """
  require Logger

  alias ShardexDemo.Catalog
  alias ShardexDemo.Tenants

  @orgs [
    %{name: "Acme Inc.", slug: "acme"},
    %{name: "Globex Corporation", slug: "globex"},
    %{name: "Initech", slug: "initech"},
    %{name: "Umbrella Corp.", slug: "umbrella"}
  ]

  @contacts %{
    "acme" => [{"Wile E. Coyote", "wile@acme.test"}, {"Road Runner", "rr@acme.test"}],
    "globex" => [{"Hank Scorpio", "hank@globex.test"}],
    "initech" => [
      {"Peter Gibbons", "peter@initech.test"},
      {"Milton Waddams", "milton@initech.test"}
    ],
    "umbrella" => [{"Alice Abernathy", "alice@umbrella.test"}]
  }

  @spec run() :: :ok
  def run do
    Enum.each(@orgs, &ensure_org/1)
    Enum.each(@orgs, fn %{slug: slug} -> ensure_contacts(slug) end)
    :ok
  end

  defp ensure_org(%{slug: slug} = attrs) do
    case Catalog.fetch_org_by_slug(slug) do
      {:ok, org} ->
        Logger.info("org #{slug} already on #{org.shard_name}")

      {:error, :not_found} ->
        {:ok, org} = Catalog.create_organization(attrs)
        Logger.info("org #{slug} created on #{org.shard_name}")
    end
  end

  defp ensure_contacts(slug) do
    case Tenants.list_contacts(slug) do
      {:ok, []} ->
        for {name, email} <- Map.get(@contacts, slug, []) do
          {:ok, _} = Tenants.create_contact(slug, %{"name" => name, "email" => email})
        end

        Logger.info("seeded contacts for #{slug}")

      {:ok, _existing} ->
        Logger.info("contacts for #{slug} already present")

      {:error, reason} ->
        Logger.warning("could not seed contacts for #{slug}: #{inspect(reason)}")
    end
  end
end
