defmodule ShardexDemoWeb.ShardScope do
  @moduledoc """
  LiveView `on_mount` hooks that bind the shard for the LiveView process.

  Why this exists: `ShardexDemo.ShardRepo.put_dynamic_repo/1` sets the dynamic
  repo in the **process dictionary**. The `TenantFromSubdomain` plug binds the
  *request* process, which covers the disconnected (dead) render — but the
  *connected* LiveView runs in its own process, which the plug never touched. So
  every tenant LiveView must rebind on mount.

  Two hooks:

    * `:tenant` — resolve the tenant and bind its shard. The tenant identity is
      recovered from `get_connect_info(socket, :uri)` (the request host) on the
      connected mount, falling back to the `tenant_slug` session value on the
      disconnected mount (where connect info is `nil`). Assigns `:current_org`
      and keeps `:shard_ref` so async work can rebind (see the moduledoc note
      below).
    * `:admin` — no shard; admin LiveViews only touch the catalog.

  Because the binding lives in the LiveView process dictionary,
  `handle_event/3`, `handle_info/2`, etc. all see it. But `start_async/3` and
  `Task`s spawn **new** processes that do NOT inherit it — inside those, rebind
  with `ShardexDemo.ShardRepo.put_dynamic_repo(socket.assigns.shard_ref)` or wrap
  the work in `ShardexDemo.Shards.run/2`.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [get_connect_info: 2, push_navigate: 2]

  alias ShardexDemo.Catalog
  alias ShardexDemo.ShardRepo
  alias ShardexDemo.Shards
  alias ShardexDemo.Tenancy

  def on_mount(:admin, _params, _session, socket) do
    {:cont, assign(socket, :current_org, nil)}
  end

  def on_mount(:tenant, _params, session, socket) do
    case tenant_slug(socket, session) do
      nil ->
        {:halt, push_navigate(socket, to: "/admin/organizations")}

      slug ->
        bind(socket, slug)
    end
  end

  defp bind(socket, slug) do
    with {:ok, org} <- Catalog.fetch_org_by_slug(slug),
         {:ok, ref} <- Shards.ref(org.slug) do
      ShardRepo.put_dynamic_repo(ref)

      {:cont,
       socket
       |> assign(:current_org, org)
       |> assign(:tenant_slug, org.slug)
       |> assign(:shard_ref, ref)}
    else
      _ -> {:halt, push_navigate(socket, to: "/admin/organizations")}
    end
  end

  # Prefer the host from connect_info (authoritative on the connected mount);
  # fall back to the session value the plug stored (covers the disconnected
  # mount, and tests where connect_info carries no tenant host).
  defp tenant_slug(socket, session) do
    from_uri =
      case get_connect_info(socket, :uri) do
        %URI{host: host} when is_binary(host) -> Tenancy.slug_from_host(host, Tenancy.base_host())
        _ -> nil
      end

    from_uri || session["tenant_slug"]
  end
end
