defmodule ShardexDemoWeb.Admin.OrganizationLive do
  @moduledoc """
  Admin area (base host): manage tenants and their shard assignments.

  Touches only the catalog. Creating an org auto-assigns a shard
  (`ShardexDemo.ShardAssignment`) unless one is chosen; reassigning calls
  `Catalog.reassign_shard/2`, which invalidates shardex's cached route.
  """
  use ShardexDemoWeb, :live_view

  alias ShardexDemo.Catalog
  alias ShardexDemo.Tenants
  alias ShardexDemo.Tenancy

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Organizations")
     |> assign(:shard_options, shard_options())
     |> assign_form(Catalog.change_organization(%ShardexDemo.Catalog.Organization{}))
     |> load_data()}
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    changeset =
      %ShardexDemo.Catalog.Organization{}
      |> Catalog.change_organization(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"organization" => params}, socket) do
    case Catalog.create_organization(params) do
      {:ok, org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created #{org.name}, assigned to #{org.shard_name}.")
         |> assign_form(Catalog.change_organization(%ShardexDemo.Catalog.Organization{}))
         |> load_data()}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("reassign", %{"org_id" => id, "shard_name" => shard_name}, socket) do
    org = Catalog.get_organization!(id)

    case Catalog.reassign_shard(org, shard_name) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Moved #{updated.name} to #{updated.shard_name} (new writes only).")
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not reassign shard.")}
    end
  end

  defp load_data(socket) do
    orgs = Catalog.list_organizations()
    org_counts = Catalog.counts_by_shard()
    contact_counts = Tenants.count_by_shard(Enum.map(orgs, & &1.slug))

    socket
    |> assign(:organizations, orgs)
    |> assign(:org_counts, org_counts)
    |> assign(:contact_counts, contact_counts)
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp shard_options, do: Enum.map(Tenancy.shard_name_strings(), &{&1, &1})

  defp tenant_url(slug) do
    uri = ShardexDemoWeb.Endpoint.struct_url()
    URI.to_string(%{uri | host: slug <> "." <> Tenancy.base_host()})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-semibold">Organizations</h1>
          <p class="text-sm text-base-content/70">
            Each tenant is assigned to a shard database. shardex routes requests to the right
            shard by looking up these assignments.
          </p>
        </div>

        <section class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div
            :for={shard <- Tenancy.shard_name_strings()}
            class="rounded-lg border border-base-300 p-4"
          >
            <div class="font-mono text-sm">{shard}</div>
            <div class="mt-1 text-sm text-base-content/70">
              {Map.get(@org_counts, shard, 0)} orgs · {Map.get(
                @contact_counts,
                String.to_existing_atom(shard),
                0
              )} contacts
            </div>
          </div>
        </section>

        <section class="rounded-lg border border-base-300 p-4">
          <h2 class="mb-3 text-lg font-medium">New organization</h2>
          <.form for={@form} id="org-form" phx-change="validate" phx-submit="save" class="space-y-4">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Acme Inc." />
            <.input field={@form[:slug]} type="text" label="Slug (subdomain)" placeholder="acme" />
            <.input
              field={@form[:shard_name]}
              type="select"
              label="Shard"
              prompt="Auto (least loaded)"
              options={@shard_options}
            />
            <.button phx-disable-with="Creating..." variant="primary">Create organization</.button>
          </.form>
        </section>

        <section>
          <h2 class="mb-3 text-lg font-medium">All organizations</h2>
          <div id="organizations" class="divide-y divide-base-300 rounded-lg border border-base-300">
            <div :if={@organizations == []} class="p-4 text-sm text-base-content/70">
              No organizations yet — create one above.
            </div>
            <div
              :for={org <- @organizations}
              id={"org-#{org.id}"}
              class="flex flex-wrap items-center justify-between gap-3 p-4"
            >
              <div>
                <div class="font-medium">{org.name}</div>
                <div class="text-sm text-base-content/70">
                  <a href={tenant_url(org.slug)} class="link link-primary">{org.slug}</a>
                  · <span class="font-mono">{org.shard_name}</span>
                </div>
              </div>
              <form id={"reassign-#{org.id}"} phx-change="reassign" class="flex items-center gap-2">
                <input type="hidden" name="org_id" value={org.id} />
                <label class="text-xs text-base-content/60">move to</label>
                <select name="shard_name" class="select select-sm select-bordered font-mono">
                  <option
                    :for={shard <- Tenancy.shard_name_strings()}
                    value={shard}
                    selected={shard == org.shard_name}
                  >
                    {shard}
                  </option>
                </select>
              </form>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
