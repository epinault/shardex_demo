defmodule ShardexDemo.Catalog.Organization do
  @moduledoc """
  A tenant, as recorded in the catalog database.

  `shard_name` is the assignment this tenant's data lives on — it is what
  `ShardexDemo.OrgDirectory` reads to route requests. It is stored as a string
  (e.g. `"shard_1"`) and validated against the configured shards.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "organizations" do
    field :slug, :string
    field :name, :string
    field :shard_name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:slug, :name, :shard_name])
    |> validate_required([:slug, :name, :shard_name])
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9-]*\z/,
      message: "must be lowercase letters, numbers and hyphens (a valid subdomain label)"
    )
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_inclusion(:shard_name, ShardexDemo.Tenancy.shard_name_strings(),
      message: "is not a known shard"
    )
    |> unique_constraint(:slug)
  end
end
