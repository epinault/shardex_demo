defmodule ShardexDemoWeb.MaintenanceTest do
  @moduledoc """
  When a tenant's shard is in maintenance, `Shards.ref/1` returns
  `{:error, :maintenance}` and the subdomain plug must answer `503` (not crash,
  not serve stale data). This drives the shard into maintenance the same way
  `mix shardex_demo.maintenance` does, just in-process (tests share the node).
  """
  use ShardexDemoWeb.ConnCase, async: false

  alias ShardexDemo.Catalog
  alias ShardexDemo.Shards

  setup %{conn: conn} do
    {:ok, _} = Catalog.create_organization(%{name: "Acme", slug: "acme", shard_name: "shard_1"})
    # Always restore routing, even if an assertion fails mid-test.
    on_exit(fn -> Shards.activate(:shard_1) end)
    {:ok, conn: %{conn | host: "acme.lvh.me"}}
  end

  test "returns 503 while the tenant's shard is drained, 200 after activate", %{conn: conn} do
    # Healthy to start.
    assert get(conn, ~p"/contacts").status == 200

    :ok = Shards.maintenance(:shard_1, :drain)
    assert {:error, :maintenance} = Shards.ref("acme")

    drained = get(%{conn | host: "acme.lvh.me"}, ~p"/contacts")
    assert drained.status == 503
    assert drained.resp_body =~ "maintenance"

    :ok = Shards.activate(:shard_1)
    assert get(%{conn | host: "acme.lvh.me"}, ~p"/contacts").status == 200
  end
end
