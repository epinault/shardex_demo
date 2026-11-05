defmodule ShardexDemo.TenancyTest do
  use ExUnit.Case, async: true

  alias ShardexDemo.Tenancy

  describe "slug_from_host/2" do
    test "extracts the subdomain label" do
      assert Tenancy.slug_from_host("acme.lvh.me", "lvh.me") == "acme"
      assert Tenancy.slug_from_host("globex.lvh.me", "lvh.me") == "globex"
    end

    test "returns nil for the base host and www" do
      assert Tenancy.slug_from_host("lvh.me", "lvh.me") == nil
      assert Tenancy.slug_from_host("www.lvh.me", "lvh.me") == nil
    end

    test "returns nil for an unrelated host" do
      assert Tenancy.slug_from_host("example.com", "lvh.me") == nil
      assert Tenancy.slug_from_host("localhost", "lvh.me") == nil
    end

    test "handles non-binary input" do
      assert Tenancy.slug_from_host(nil, "lvh.me") == nil
    end
  end

  describe "config helpers" do
    test "shard_names/0 reflects configured shards" do
      assert Tenancy.shard_names() == [:shard_1, :shard_2]
      assert Tenancy.shard_name_strings() == ["shard_1", "shard_2"]
    end
  end
end
