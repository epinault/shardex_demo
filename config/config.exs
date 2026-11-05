# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Only the catalog repo is a "standard" Ecto repo. ShardexDemo.ShardRepo is
# driven by shardex (dynamic mode, one repo → many databases), so it is
# deliberately NOT listed here — otherwise `mix ecto.*` and the generators would
# try to manage a database-less default instance that collides with the shard
# pools shardex starts.
config :shardex_demo,
  ecto_repos: [ShardexDemo.CatalogRepo],
  generators: [timestamp_type: :utc_datetime]

# The base host used to derive the tenant subdomain (e.g. "acme" from
# "acme.lvh.me"). `lvh.me` resolves to 127.0.0.1 via public DNS; switch this to
# "localhost" (and use `*.localhost`) when offline.
config :shardex_demo, :base_host, "lvh.me"

# Configure the endpoint
config :shardex_demo, ShardexDemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ShardexDemoWeb.ErrorHTML, json: ShardexDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ShardexDemo.PubSub,
  live_view: [signing_salt: "Jf2I6/a5"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  shardex_demo: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  shardex_demo: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
