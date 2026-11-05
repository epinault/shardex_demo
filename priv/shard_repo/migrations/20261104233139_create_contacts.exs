defmodule ShardexDemo.ShardRepo.Migrations.CreateContacts do
  use Ecto.Migration

  # This one migration set is applied to EVERY shard database (see
  # `mix shardex_demo.migrate_shards`). Every shard has the identical schema;
  # `org_slug` scopes rows to a tenant *within* the shard, since a shard holds
  # data for many tenants.
  def change do
    create table(:contacts) do
      add :org_slug, :string, null: false
      add :name, :string, null: false
      add :email, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:org_slug])
  end
end
