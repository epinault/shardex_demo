-- Creates the catalog + shard databases for the demo (dev and test).
--
-- The shard databases are NOT in :ecto_repos, so `mix ecto.create` does not know
-- about them; `mix shardex_demo.setup_shards` can also create them, but when you
-- run Postgres via docker-compose this script sets everything up on first boot.
--
-- This runs only when the data volume is empty. To re-run it, reset the volume:
--   docker compose down -v && docker compose up -d

CREATE DATABASE shardex_demo_catalog_dev;
CREATE DATABASE shardex_demo_shard_1_dev;
CREATE DATABASE shardex_demo_shard_2_dev;

CREATE DATABASE shardex_demo_catalog_test;
CREATE DATABASE shardex_demo_shard_1_test;
CREATE DATABASE shardex_demo_shard_2_test;
