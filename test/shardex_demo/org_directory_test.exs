defmodule ShardexDemo.OrgDirectoryTest do
  @moduledoc """
  Unit test for the custom routing strategy. We call `route_many/2` directly
  against the catalog (sandboxed), independent of the live shardex instance.
  """
  use ShardexDemo.DataCase, async: true

  alias ShardexDemo.Catalog
  alias ShardexDemo.OrgDirectory

  @ctx %{shards: [:shard_1, :shard_2], state: nil, instance: ShardexDemo.Shards}

  setup do
    {:ok, _} = Catalog.create_organization(%{name: "Acme", slug: "acme", shard_name: "shard_1"})

    {:ok, _} =
      Catalog.create_organization(%{name: "Globex", slug: "globex", shard_name: "shard_2"})

    :ok
  end

  test "resolves known slugs to their assigned shard atoms" do
    assert OrgDirectory.route_many(["acme", "globex"], @ctx) == %{
             "acme" => {:ok, :shard_1},
             "globex" => {:ok, :shard_2}
           }
  end

  test "unknown slugs are :not_found" do
    assert OrgDirectory.route_many(["ghost"], @ctx) == %{"ghost" => {:error, :not_found}}
  end

  test "a slug assigned to a shard that isn't configured is rejected" do
    {:ok, _} = Catalog.create_organization(%{name: "Odd", slug: "odd", shard_name: "shard_1"})
    # Pretend the running instance only knows shard_2.
    ctx = %{@ctx | shards: [:shard_2]}

    assert OrgDirectory.route_many(["odd"], ctx) == %{
             "odd" => {:error, {:unknown_shard, "shard_1"}}
           }
  end

  test "deduplicates keys" do
    assert OrgDirectory.route_many(["acme", "acme"], @ctx) == %{"acme" => {:ok, :shard_1}}
  end
end
