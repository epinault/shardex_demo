defmodule ShardexDemo.CatalogRepo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :shard_name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug])
    create index(:organizations, [:shard_name])
  end
end
