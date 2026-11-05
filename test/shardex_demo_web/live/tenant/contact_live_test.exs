defmodule ShardexDemoWeb.Tenant.ContactLiveTest do
  @moduledoc """
  Exercises the full tenant path: subdomain resolution in the plug, the
  connected LiveView process rebinding to the tenant's shard (ShardScope), and
  per-tenant data served from that shard.
  """
  use ShardexDemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ShardexDemo.ShardHelpers, only: [reset_shards!: 0]

  alias ShardexDemo.Catalog
  alias ShardexDemo.Tenants

  setup %{conn: conn} do
    reset_shards!()
    # acme → shard_1 under the static test strategy; the catalog row is needed
    # for the plug + on_mount lookup.
    {:ok, _} = Catalog.create_organization(%{name: "Acme", slug: "acme", shard_name: "shard_1"})

    {:ok, _} =
      Catalog.create_organization(%{name: "Globex", slug: "globex", shard_name: "shard_2"})

    {:ok, conn: %{conn | host: "acme.lvh.me"}}
  end

  test "shows the current tenant's contacts", %{conn: conn} do
    {:ok, _} = Tenants.create_contact("acme", %{"name" => "Ann Acme", "email" => "ann@acme.test"})

    {:ok, _} =
      Tenants.create_contact("globex", %{"name" => "Gil Globex", "email" => "gil@globex.test"})

    {:ok, lv, _html} = live(conn, ~p"/contacts")

    html = render(lv)
    assert html =~ "Ann Acme"
    # A different tenant's contact (on another shard) must not appear.
    refute html =~ "Gil Globex"
  end

  test "adding a contact persists to the tenant's shard", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/contacts")

    lv
    |> form("#contact-form", contact: %{name: "New Person", email: "new@acme.test"})
    |> render_submit()

    assert render(lv) =~ "New Person"

    {:ok, acme} = Tenants.list_contacts("acme")
    assert Enum.any?(acme, &(&1.name == "New Person"))

    # And it did not leak into the other shard.
    {:ok, globex} = Tenants.list_contacts("globex")
    assert globex == []
  end

  test "unknown subdomain returns 404 at the plug", %{conn: conn} do
    conn = %{conn | host: "ghost.lvh.me"}
    conn = get(conn, ~p"/contacts")
    assert conn.status == 404
  end
end
