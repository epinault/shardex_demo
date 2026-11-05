defmodule ShardexDemoWeb.PageController do
  use ShardexDemoWeb, :controller

  # Root path. `:current_org` was set by TenantFromSubdomain: present on a tenant
  # subdomain, nil on the base host (admin).
  def home(conn, _params) do
    case conn.assigns[:current_org] do
      nil -> redirect(conn, to: ~p"/admin/organizations")
      _org -> redirect(conn, to: ~p"/contacts")
    end
  end
end
