defmodule ShardexDemoWeb.Router do
  use ShardexDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShardexDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Must come after :fetch_session (it writes the session) and is the last
    # plug so assigns/bindings are in place for controllers and dead renders.
    plug ShardexDemoWeb.Plugs.TenantFromSubdomain
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShardexDemoWeb do
    pipe_through :browser

    # Root: send admins to the org list, tenants to their contacts.
    get "/", PageController, :home

    # Admin area — lives on the base host (no subdomain). Touches the catalog only.
    live_session :admin, on_mount: {ShardexDemoWeb.ShardScope, :admin} do
      live "/admin/organizations", Admin.OrganizationLive, :index
    end

    # Tenant area — lives on a tenant subdomain. Routed to the tenant's shard.
    live_session :tenant, on_mount: {ShardexDemoWeb.ShardScope, :tenant} do
      live "/contacts", Tenant.ContactLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShardexDemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:shardex_demo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShardexDemoWeb.Telemetry
    end
  end
end
