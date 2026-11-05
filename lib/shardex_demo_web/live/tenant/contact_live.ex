defmodule ShardexDemoWeb.Tenant.ContactLive do
  @moduledoc """
  Tenant area (on a tenant subdomain): list and create the current tenant's
  contacts.

  The LiveView process was bound to the tenant's shard by
  `ShardexDemoWeb.ShardScope` on mount, so plain `ShardRepo` calls (via
  `Tenants.list_contacts_bound/1`) hit the right database. Writes go through
  `Tenants.create_contact/2`, which routes explicitly with `Shards.run/2`.
  """
  use ShardexDemoWeb, :live_view

  alias ShardexDemo.Tenants
  alias ShardexDemo.Tenants.Contact

  @impl true
  def mount(_params, _session, socket) do
    org = socket.assigns.current_org

    {:ok,
     socket
     |> assign(:page_title, "#{org.name} · Contacts")
     |> assign_form(Tenants.change_contact(%Contact{}))
     |> stream(:contacts, Tenants.list_contacts_bound(org.slug))}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    changeset =
      %Contact{}
      |> Tenants.change_contact(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"contact" => params}, socket) do
    slug = socket.assigns.current_org.slug

    case Tenants.create_contact(slug, params) do
      {:ok, contact} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{contact.name}.")
         |> assign_form(Tenants.change_contact(%Contact{}))
         |> stream_insert(:contacts, contact, at: 0)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not reach this tenant's shard (#{inspect(reason)}).")}
    end
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-semibold">{@current_org.name}</h1>
          <p class="text-sm text-base-content/70">
            Contacts for <span class="font-mono">{@current_org.slug}</span>, served from shard <span class="font-mono">{@current_org.shard_name}</span>.
          </p>
        </div>

        <section class="rounded-lg border border-base-300 p-4">
          <h2 class="mb-3 text-lg font-medium">New contact</h2>
          <.form
            for={@form}
            id="contact-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input field={@form[:name]} type="text" label="Name" placeholder="Jane Doe" />
            <.input field={@form[:email]} type="text" label="Email" placeholder="jane@example.com" />
            <.button phx-disable-with="Adding..." variant="primary">Add contact</.button>
          </.form>
        </section>

        <section>
          <h2 class="mb-3 text-lg font-medium">Contacts</h2>
          <div
            id="contacts"
            phx-update="stream"
            class="divide-y divide-base-300 rounded-lg border border-base-300"
          >
            <div id="contacts-empty" class="hidden p-4 text-sm text-base-content/70 only:block">
              No contacts yet — add one above.
            </div>
            <div :for={{id, contact} <- @streams.contacts} id={id} class="p-4">
              <div class="font-medium">{contact.name}</div>
              <div class="text-sm text-base-content/70">{contact.email}</div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
