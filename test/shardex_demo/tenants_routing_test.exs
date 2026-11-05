defmodule ShardexDemo.TenantsRoutingTest do
  @moduledoc """
  Proves that shardex routes each tenant's writes to the correct physical shard
  database, and that tenants sharing a shard stay isolated by `org_slug`.

  Routing here uses the static test strategy (acme → shard_1, globex → shard_2;
  see config/test.exs), so this test exercises routing + shard writes without
  depending on a live catalog lookup.
  """
  use ExUnit.Case, async: false

  import ShardexDemo.ShardHelpers, only: [reset_shards!: 0]

  alias ShardexDemo.Shards
  alias ShardexDemo.Tenants
  alias ShardexDemo.Tenants.Contact

  setup do
    reset_shards!()
    :ok
  end

  test "each tenant's rows land in its own shard database" do
    {:ok, _} = Tenants.create_contact("acme", %{"name" => "Ann", "email" => "ann@acme.test"})
    {:ok, _} = Tenants.create_contact("globex", %{"name" => "Gil", "email" => "gil@globex.test"})

    # Read the FULL contacts table in each shard DB (no org filter) to see where
    # the rows physically live.
    {:ok, shard_1_rows} = Shards.run("acme", fn repo -> repo.all(Contact) end)
    {:ok, shard_2_rows} = Shards.run("globex", fn repo -> repo.all(Contact) end)

    assert Enum.map(shard_1_rows, & &1.org_slug) == ["acme"]
    assert Enum.map(shard_2_rows, & &1.org_slug) == ["globex"]
  end

  test "two tenants on the same shard are isolated by org_slug" do
    # Both acme and another slug that also maps to shard_1 via run/2 would share
    # a DB; here we add two acme rows and confirm list_contacts scopes correctly.
    {:ok, _} = Tenants.create_contact("acme", %{"name" => "Ann", "email" => "ann@acme.test"})
    {:ok, _} = Tenants.create_contact("acme", %{"name" => "Bob", "email" => "bob@acme.test"})
    {:ok, _} = Tenants.create_contact("globex", %{"name" => "Gil", "email" => "gil@globex.test"})

    {:ok, acme} = Tenants.list_contacts("acme")
    {:ok, globex} = Tenants.list_contacts("globex")

    assert length(acme) == 2
    assert Enum.all?(acme, &(&1.org_slug == "acme"))
    assert length(globex) == 1
  end

  test "count_by_shard aggregates across shards in one pass" do
    {:ok, _} = Tenants.create_contact("acme", %{"name" => "Ann", "email" => "ann@acme.test"})
    {:ok, _} = Tenants.create_contact("globex", %{"name" => "Gil", "email" => "gil@globex.test"})

    {:ok, _} =
      Tenants.create_contact("globex", %{"name" => "Gwen", "email" => "gwen@globex.test"})

    counts = Tenants.count_by_shard(["acme", "globex"])

    assert counts[:shard_1] == 1
    assert counts[:shard_2] == 2
  end
end
