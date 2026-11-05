# ShardexDemo

A small Phoenix + LiveView app that demonstrates **tenant-based Postgres
sharding** with [`shardex`](https://github.com/epinault/shardex).

`shardex` is a key → pool router: you give it a key and it routes to the right
backend pool. This demo uses it the multi-tenant way — each **organization**
(tenant) is assigned to a **shard database**, and every request is routed to its
tenant's shard. The custom wiring you'd write in a real app is all here, and
small on purpose:

- an **organizations catalog table** that records each tenant's shard assignment;
- a **custom `shardex` strategy** (`ShardexDemo.OrgDirectory`) that resolves a
  tenant slug → shard by reading that table (cached);
- a **custom assignment policy** (`ShardexDemo.ShardAssignment`) that picks a
  shard for a new tenant (least-loaded here — swap in your own);
- a **subdomain plug** that identifies the tenant per request;
- a **LiveView `on_mount` hook** that rebinds the shard on the connected socket.

> Scope: Postgres only, `:primary` role only, two shards + one catalog database.

## How it works

```
                        acme.lvh.me                 globex.lvh.me
                             │                            │
                 TenantFromSubdomain plug      (slug = "acme" / "globex")
                             │
          Catalog (unsharded) ── organizations: slug → shard_name
                             │
                 ShardexDemo.Shards (shardex instance)
                   strategy: Cached(OrgDirectory)
                   ┌──────────────┴───────────────┐
             shard_1 database                shard_2 database
             (acme, initech, …)              (globex, umbrella, …)
             contacts.org_slug               contacts.org_slug
```

A shard database holds data for **many** tenants, so per-tenant tables
(`contacts`) carry an `org_slug` column: `shardex` picks the *database*, and
`org_slug` scopes rows to the tenant *within* it.

## The shardex pieces (and where they live)

Each `shardex` concept maps to one place in this app. The first three are
`shardex`'s own extension points; the rest is the glue a host app provides.

| `shardex` concept | What it does | In this app |
|---|---|---|
| **Instance** (`use Shardex`) | owns the shards; exposes `ref/1`, `run/2`, `run_batch/4`, `shards/0`, `invalidate/1` | `ShardexDemo.Shards` — [`lib/shardex_demo/shards.ex`](lib/shardex_demo/shards.ex) |
| **Strategy** (`@behaviour Shardex.Strategy`) | maps a key → shard (the *resolution* hook) | `ShardexDemo.OrgDirectory` — [`lib/shardex_demo/org_directory.ex`](lib/shardex_demo/org_directory.ex), wrapped in `Shardex.Strategy.Cached` |
| **Ecto adapter**, dynamic mode (`Shardex.Adapter.Ecto`) | one repo module → many Postgres databases | `ShardexDemo.ShardRepo` — [`lib/shardex_demo/shard_repo.ex`](lib/shardex_demo/shard_repo.ex); topology + strategy in [`config/dev.exs`](config/dev.exs) |
| **Routing a request** (`ref/1` + `put_dynamic_repo/1`) | bind the tenant's shard for the request process | `ShardexDemoWeb.Plugs.TenantFromSubdomain` — [`lib/shardex_demo_web/plugs/tenant_from_subdomain.ex`](lib/shardex_demo_web/plugs/tenant_from_subdomain.ex) |
| **LiveView rebinding** | rebind the shard on the *connected* LV process (dynamic repos are per-process) | `ShardexDemoWeb.ShardScope` (`on_mount`) — [`lib/shardex_demo_web/shard_scope.ex`](lib/shardex_demo_web/shard_scope.ex); endpoint socket `connect_info: [:uri, …]` in [`endpoint.ex`](lib/shardex_demo_web/endpoint.ex) |
| **Running scoped queries** (`run/2`, `run_batch/4`) | execute against the routed shard, scoped by `org_slug` | `ShardexDemo.Tenants` — [`lib/shardex_demo/tenants.ex`](lib/shardex_demo/tenants.ex) |
| **Assignment** (your own policy) | pick a shard for a *new* tenant | `ShardexDemo.ShardAssignment` — [`lib/shardex_demo/shard_assignment.ex`](lib/shardex_demo/shard_assignment.ex) |
| **The directory** the strategy reads | source of truth for slug → shard | `organizations` table + `ShardexDemo.Catalog` — [`lib/shardex_demo/catalog.ex`](lib/shardex_demo/catalog.ex) |
| **Cache invalidation** (`invalidate/1`) | drop a stale route after reassignment | `Catalog.reassign_shard/2` in [`lib/shardex_demo/catalog.ex`](lib/shardex_demo/catalog.ex) |
| **Migrations** (shardex runs none) | migrate every shard DB | `mix shardex_demo.migrate_shards` — [`lib/mix/tasks/shardex_demo.migrate_shards.ex`](lib/mix/tasks/shardex_demo.migrate_shards.ex) |

The two tenant identifiers used as `shardex` **keys** are organization slugs
(e.g. `"acme"`), resolved from the request subdomain.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full walkthrough,
including the per-process dynamic-repo rule that makes the `on_mount` hook
necessary.

## Quickstart

Requires Elixir/Erlang (see `.tool-versions`) and Docker.

```bash
# 1. Postgres + all databases (catalog + 2 shards, dev + test)
docker compose up -d

# 2. Deps, migrate catalog + every shard, seed demo tenants
mix setup

# 3. Run it
mix phx.server
```

Then visit:

- **Admin** — <http://lvh.me:4000/admin/organizations> — create tenants and
  (re)assign shards. `lvh.me` resolves to `127.0.0.1`.
- **A tenant** — <http://acme.lvh.me:4000/contacts> and
  <http://globex.lvh.me:4000/contacts> — each sees only its own contacts, served
  from its assigned shard.

Prove the routing at the database level:

```bash
docker exec shardex_demo_db psql -U postgres -d shardex_demo_shard_1_dev \
  -c "select org_slug, count(*) from contacts group by org_slug;"
docker exec shardex_demo_db psql -U postgres -d shardex_demo_shard_2_dev \
  -c "select org_slug, count(*) from contacts group by org_slug;"
```

### Port already in use?

If something already listens on 5432, run Postgres on another port and pass it
to every `mix` command:

```bash
SHARDEX_DEMO_PGPORT=5433 docker compose up -d
SHARDEX_DEMO_PGPORT=5433 mix setup
SHARDEX_DEMO_PGPORT=5433 mix phx.server
```

## Commands

| Command | What it does |
|---|---|
| `docker compose up -d` | Postgres + all databases (initdb SQL creates them) |
| `mix setup` | deps, create/migrate catalog + shards, seed, build assets |
| `mix shardex_demo.setup_shards` | create the shard databases (not in `:ecto_repos`) |
| `mix shardex_demo.migrate_shards` | migrate every shard (`priv/shard_repo/migrations`) |
| `mix shardex_demo.seed` | insert demo tenants + contacts (idempotent) |
| `mix ecto.reset` | drop + recreate + migrate + seed everything |
| `mix test` | full suite (sets up catalog + shard test DBs first) |
| `mix precommit` | compile (warnings as errors), format, test |

To wipe everything (including the shard databases): `docker compose down -v`.

## Tests

- `test/shardex_demo/tenancy_test.exs` — subdomain → slug parsing (pure).
- `test/shardex_demo/org_directory_test.exs` — the custom strategy against the catalog.
- `test/shardex_demo/tenants_routing_test.exs` — writes land in the correct shard DB.
- `test/shardex_demo_web/live/**` — subdomain resolution, `on_mount` rebinding, isolation.

## License

MIT
