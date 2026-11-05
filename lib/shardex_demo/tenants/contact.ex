defmodule ShardexDemo.Tenants.Contact do
  @moduledoc """
  A per-tenant record that lives in a **shard** database.

  A single shard database holds data for *many* tenants (many organizations can
  be assigned to `shard_1`), so every row carries `org_slug`. shardex picks the
  right database; `org_slug` scopes rows to the right tenant *within* that
  database. `org_slug` is set programmatically from the current tenant, never
  from user input, so it is not part of `cast/3`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "contacts" do
    field :org_slug, :string
    field :name, :string
    field :email, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
  end
end
