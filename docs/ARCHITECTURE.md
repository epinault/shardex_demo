# Architecture

This demo shows how to use [`shardex`](https://github.com/epinault/shardex) for
tenant-based Postgres sharding in a Phoenix app. This document explains each
moving part and the one non-obvious rule that shapes the web layer.

## The mental model

`shardex` is a **key → pool router**. It does not do schema-per-tenant or query
prefixes (it is not Triplex/Apartment). You hand it a key; it routes to a backend
pool. With the Ecto adapter in **dynamic mode**, one repo module
(`ShardexDemo.ShardRepo`) fronts many Postgres *databases*, and the pool is
selected per process via `Ecto.Repo.put_dynamic_repo/1`.

Tenancy is a policy we layer on top: the key is an organization slug, and the
"pool" is that tenant's shard database.

## The pieces

### Two repos

| Repo | Role |
|---|---|
| `ShardexDemo.CatalogRepo` | One unsharded database. Holds `organizations` (the tenant → shard directory). The only repo in `:ecto_repos`. |
| `ShardexDemo.ShardRepo` | Dynamic-mode repo. `shardex` starts it **once per shard** under a distinct dynamic name with a per-shard `database:`. Not in `:ecto_repos`, not in the supervision tree. |

If you put `ShardRepo` in `:ecto_repos` or the tree, Ecto would start a
database-less default instance that collides with the shard pools — so it is
deliberately absent.

### The shardex instance

`ShardexDemo.Shards` (`use Shardex, otp_app: :shardex_demo`) is configured in
`config/*.exs`:

```elixir
config :shardex_demo, ShardexDemo.Shards,
  strategy: {Shardex.Strategy.Cached, inner: ShardexDemo.OrgDirectory, ttl: :timer.minutes(10)},
  shards: [
    shard_1: {Shardex.Adapter.Ecto, repo: ShardexDemo.ShardRepo, config: [database: "shardex_demo_shard_1_dev"]},
    shard_2: {Shardex.Adapter.Ecto, repo: ShardexDemo.ShardRepo, config: [database: "shardex_demo_shard_2_dev"]}
  ]
```

It is in the supervision tree **after** `CatalogRepo`, because the routing
strategy reads from the catalog.

### Custom logic #1 — resolution (`ShardexDemo.OrgDirectory`)

The `shardex` strategy. `route_many/2` receives a batch of tenant slugs and
returns each one's shard by reading `organizations.shard_name` from the catalog.
Wrapped in `Shardex.Strategy.Cached`, so the catalog is only hit on a cache
miss. Keys are **slugs** everywhere (the subdomain hands us a slug for free).
Stored shard names are turned into atoms only with `String.to_existing_atom/1`,
and only after validating against the configured shards.

### Custom logic #2 — assignment (`ShardexDemo.ShardAssignment`)

When a *new* tenant is created, which shard should it get? `pick_shard/0`
chooses the least-loaded shard (fewest orgs in the catalog). Swap in hashing, a
region map, a capacity table, or manual placement — nothing else changes.

When an assignment changes, `Catalog.reassign_shard/2` calls
`Shards.invalidate/1` **after** the commit so the cache drops the stale route.
(Reassignment does not move existing rows — routing is by connection — so the
demo treats assignment as effectively create-time.)

### Per-tenant data

A shard database holds **many** tenants. So `contacts` carries an `org_slug`
column: `shardex` selects the database, and `org_slug` scopes rows to the tenant
within it. `ShardexDemo.Tenants` shows both ways to run a shard query:

- `Shards.run(slug, fn repo -> ... end)` — `shardex` binds the dynamic repo for
  the duration and restores it. Used for writes and background work.
- Rely on an ambient binding already set on the process (see below), then call
  `ShardRepo.*` directly.

## The non-obvious rule: dynamic repos are per-process

`put_dynamic_repo/1` writes the **process dictionary**. That has consequences
for the web layer:

1. **`ShardexDemoWeb.Plugs.TenantFromSubdomain`** resolves the tenant from
   `conn.host`, assigns `:current_org`, stashes `tenant_slug` in the session, and
   binds the shard for the **request process**. This covers controllers and the
   LiveView *disconnected* (dead) render.

2. **`ShardexDemoWeb.ShardScope`** (`on_mount`) rebinds the shard for the
   **connected** LiveView process — a different process the plug never touched.
   It recovers the tenant from `get_connect_info(socket, :uri)` (the host),
   falling back to the session `tenant_slug`. Admin LiveViews use the `:admin`
   hook (catalog only, no binding).

3. **`start_async` / `Task`** spawn *new* processes that do **not** inherit the
   binding. Inside them, rebind with
   `ShardRepo.put_dynamic_repo(socket.assigns.shard_ref)` or wrap the work in
   `Shards.run/2`.

The endpoint enables `connect_info: [:uri, session: ...]` so (2) can read the
host on the connected mount.

## Request flow

```
GET acme.lvh.me/contacts
  → endpoint → :browser pipeline
  → TenantFromSubdomain: host "acme.lvh.me" → slug "acme"
       → Catalog.fetch_org_by_slug("acme") → %Organization{shard_name: "shard_1"}
       → Shards.ref("acme") → dynamic repo name for shard_1
       → ShardRepo.put_dynamic_repo(name)      # request process
  → ContactLive dead render (request process, already bound)
  → websocket connect (connect_info carries the host + session)
  → ShardScope :tenant on_mount (connected process)
       → recover slug "acme" → Shards.ref → ShardRepo.put_dynamic_repo(name)
  → ContactLive mount reads ShardRepo (now bound to shard_1), scoped by org_slug
```

## Migrations

`shardex` does not run migrations. Catalog migrations live in
`priv/catalog_repo/migrations` and run with plain `mix ecto.migrate`. Shard
migrations live in `priv/shard_repo/migrations` — one set, applied to every
shard by `mix shardex_demo.migrate_shards`, which enumerates `Shards.shards()`
and runs `Ecto.Migrator` against each pool's `dynamic_name` (its own
`schema_migrations` table per shard).

## Testing

- **Catalog** uses the Ecto SQL sandbox (fast, isolated; `async: true` where
  catalog-only).
- **Shards** are *not* sandboxed: their pools run under `shardex`'s dynamic
  names and the connected-LiveView process is separate, both of which make the
  sandbox awkward. Instead, shard-touching tests truncate the shard tables
  between runs (`ShardexDemo.ShardHelpers.reset_shards!/0`) and run
  `async: false`.
- Routing in the test env uses `Shardex.Strategy.Static` (acme → shard_1,
  globex → shard_2) to isolate "routing + shard writes work" from "the catalog
  lookup works" (the latter is covered by `OrgDirectoryTest`).
