ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ShardexDemo.CatalogRepo, :manual)

# Shard databases aren't sandboxed (see config/test.exs). Start each test run
# from clean shard tables so shard-touching tests are deterministic.
ShardexDemo.ShardHelpers.reset_shards!()
