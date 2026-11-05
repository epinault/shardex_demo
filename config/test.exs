import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
pg_port = String.to_integer(System.get_env("SHARDEX_DEMO_PGPORT") || "5432")

config :shardex_demo, ShardexDemo.CatalogRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: pg_port,
  database: "shardex_demo_catalog_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Shard repo base config (no `:database` — merged per shard below).
#
# The shard repo deliberately does NOT use the SQL sandbox. Its pools run under
# shardex's dynamic names (not the `ShardexDemo.ShardRepo` module), and the
# connected-LiveView process is separate from the test process — both make the
# sandbox awkward here. Instead, shard-touching tests reset the shard tables
# between runs (see `ShardexDemo.ShardHelpers`) and run `async: false`.
config :shardex_demo, ShardexDemo.ShardRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: pg_port,
  pool_size: 5

# In tests we route with a deterministic static map instead of the live
# database-backed directory. This isolates "routing + shard writes work" from
# "the catalog lookup works" (the latter is covered by OrgDirectoryTest, which
# calls `route_many/2` directly). `#{System.get_env("MIX_TEST_PARTITION")}` is
# appended to database names so partitioned CI runs stay isolated.
config :shardex_demo, ShardexDemo.Shards,
  strategy: {Shardex.Strategy.Static, map: %{"acme" => :shard_1, "globex" => :shard_2}},
  shards: [
    shard_1:
      {Shardex.Adapter.Ecto,
       repo: ShardexDemo.ShardRepo,
       config: [database: "shardex_demo_shard_1_test#{System.get_env("MIX_TEST_PARTITION")}"]},
    shard_2:
      {Shardex.Adapter.Ecto,
       repo: ShardexDemo.ShardRepo,
       config: [database: "shardex_demo_shard_2_test#{System.get_env("MIX_TEST_PARTITION")}"]}
  ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shardex_demo, ShardexDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LPPBFJqiEjr1hrqMhKpg/WiYYTLwgGZ3ejthaOEze0b/pi8FpPk9QykwK4O+BK/6",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
