defmodule ShardexDemoWeb.Admin.OrganizationLiveTest do
  use ShardexDemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import ShardexDemo.ShardHelpers, only: [reset_shards!: 0]

  alias ShardexDemo.Catalog

  setup %{conn: conn} do
    reset_shards!()
    # Admin lives on the base host (no subdomain).
    {:ok, conn: %{conn | host: "lvh.me"}}
  end

  test "lists organizations", %{conn: conn} do
    {:ok, _} = Catalog.create_organization(%{name: "Acme", slug: "acme", shard_name: "shard_1"})

    {:ok, lv, _html} = live(conn, ~p"/admin/organizations")

    assert has_element?(lv, "#org-form")
    assert render(lv) =~ "acme"
  end

  test "creating an organization with an explicit shard", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/admin/organizations")

    lv
    |> form("#org-form", organization: %{name: "Globex", slug: "globex", shard_name: "shard_2"})
    |> render_submit()

    assert render(lv) =~ "globex"
    assert {:ok, org} = Catalog.fetch_org_by_slug("globex")
    assert org.shard_name == "shard_2"
  end

  test "auto-assigns a shard when none is chosen", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/admin/organizations")

    lv
    |> form("#org-form", organization: %{name: "Initech", slug: "initech", shard_name: ""})
    |> render_submit()

    assert {:ok, org} = Catalog.fetch_org_by_slug("initech")
    assert org.shard_name in ShardexDemo.Tenancy.shard_name_strings()
  end

  test "invalid slug shows a validation error", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/admin/organizations")

    html =
      lv
      |> form("#org-form",
        organization: %{name: "Bad", slug: "Not A Slug", shard_name: "shard_1"}
      )
      |> render_submit()

    assert html =~ "valid subdomain label"
    assert {:error, :not_found} = Catalog.fetch_org_by_slug("Not A Slug")
  end
end
