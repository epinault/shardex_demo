defmodule ShardexDemoWeb.Plugs.TenantFromSubdomain do
  @moduledoc """
  Resolves the tenant from the request's subdomain and binds the shard for the
  **request process**.

  On every browser request this plug:

    1. derives a slug from `conn.host` (e.g. `acme` from `acme.lvh.me`);
    2. with no slug (the bare base host) assigns `current_org: nil` — this is the
       admin area;
    3. with a slug, looks the org up in the catalog and, on success, assigns
       `current_org`, stashes `tenant_slug` in the session (a fallback for the
       connected LiveView mount), and binds `ShardexDemo.ShardRepo`'s dynamic
       repo to the tenant's shard via `ShardexDemo.Shards.ref/1`.

  The dynamic-repo binding here lives in the **request process**, so it covers
  controllers and the LiveView *disconnected* (dead) render. The *connected*
  LiveView process is a different process and rebinds itself — see
  `ShardexDemoWeb.ShardScope`.
  """
  import Plug.Conn

  alias ShardexDemo.Catalog
  alias ShardexDemo.ShardRepo
  alias ShardexDemo.Shards
  alias ShardexDemo.Tenancy

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case Tenancy.slug_from_host(conn.host, Tenancy.base_host()) do
      nil ->
        # Admin area (no tenant).
        conn
        |> assign(:current_org, nil)
        |> delete_session(:tenant_slug)

      slug ->
        resolve_tenant(conn, slug)
    end
  end

  defp resolve_tenant(conn, slug) do
    case Catalog.fetch_org_by_slug(slug) do
      {:ok, org} -> bind_shard(conn, org)
      {:error, :not_found} -> halt_with(conn, 404, "Unknown tenant: #{slug}")
    end
  end

  defp bind_shard(conn, org) do
    case Shards.ref(org.slug) do
      {:ok, dynamic_name} ->
        ShardRepo.put_dynamic_repo(dynamic_name)

        conn
        |> assign(:current_org, org)
        |> put_session(:tenant_slug, org.slug)

      {:error, :maintenance} ->
        halt_with(conn, 503, "This tenant's shard is under maintenance. Try again shortly.")

      {:error, reason} ->
        halt_with(conn, 500, "No shard available for #{org.slug} (#{inspect(reason)})")
    end
  end

  defp halt_with(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
    |> halt()
  end
end
