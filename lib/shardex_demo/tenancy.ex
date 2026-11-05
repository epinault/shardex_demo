defmodule ShardexDemo.Tenancy do
  @moduledoc """
  Small helpers that tie HTTP requests to tenants and shards.

  * `slug_from_host/2` turns a request host into a tenant slug (the subdomain).
  * `base_host/0` is the configured base domain (`:base_host`).
  * `shard_names/0` lists the configured shard names, read straight from the
    `ShardexDemo.Shards` config so neither the admin UI nor changeset validation
    needs the shard pools to be running.
  """

  @doc """
  Extracts the tenant slug from a request host.

  Returns `nil` for the bare base host (or its `www.`), which is the admin area:

      iex> ShardexDemo.Tenancy.slug_from_host("acme.lvh.me", "lvh.me")
      "acme"
      iex> ShardexDemo.Tenancy.slug_from_host("lvh.me", "lvh.me")
      nil
      iex> ShardexDemo.Tenancy.slug_from_host("www.lvh.me", "lvh.me")
      nil
  """
  @spec slug_from_host(String.t(), String.t()) :: String.t() | nil
  def slug_from_host(host, base) when is_binary(host) and is_binary(base) do
    suffix = "." <> base

    cond do
      host in [base, "www." <> base] ->
        nil

      String.ends_with?(host, suffix) ->
        host |> String.replace_suffix(suffix, "") |> String.split(".") |> List.last()

      true ->
        nil
    end
  end

  def slug_from_host(_host, _base), do: nil

  @doc "The configured base host (e.g. \"lvh.me\")."
  @spec base_host() :: String.t()
  def base_host, do: Application.fetch_env!(:shardex_demo, :base_host)

  @doc "The configured shard names as atoms, e.g. `[:shard_1, :shard_2]`."
  @spec shard_names() :: [atom()]
  def shard_names do
    :shardex_demo
    |> Application.get_env(ShardexDemo.Shards, [])
    |> Keyword.get(:shards, [])
    |> Keyword.keys()
  end

  @doc "The configured shard names as strings, e.g. `[\"shard_1\", \"shard_2\"]`."
  @spec shard_name_strings() :: [String.t()]
  def shard_name_strings, do: Enum.map(shard_names(), &Atom.to_string/1)
end
