defmodule CaeWeb.Admin.StaffLive do
  use CaeWeb, :live_view

  alias Cae.Accounts

  @roles [
    {"Psicologo", "psychologist"},
    {"Psiquiatra", "psychiatrist"},
    {"Psicopedagogo", "psychopedagogue"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Gestion del Staff")
     |> assign(:current_scope, socket.assigns[:current_scope])
     |> assign(:staff, load_staff())
     |> assign(:roles, @roles)
     |> assign(:form, professional_form())}
  end

  @impl true
  def handle_event("save_professional", %{"professional" => params}, socket) do
    case Accounts.create_professional(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:staff, load_staff())
         |> assign(:form, professional_form())
         |> put_flash(:info, "Profesional creado correctamente")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset, as: :professional))
         |> put_flash(:error, first_error(changeset) || "No se pudo crear el profesional")}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    with {user_id, ""} <- Integer.parse(id),
         user <- Accounts.get_user!(user_id),
         true <- professional_role?(user.role) do
      result =
        if user.is_active,
          do: Accounts.deactivate_user(user),
          else: Accounts.reactivate_user(user)

      case result do
        {:ok, _} ->
          message =
            if user.is_active,
              do: "Profesional marcado como inactivo",
              else: "Profesional reactivado"

          {:noreply,
           socket
           |> assign(:staff, load_staff())
           |> put_flash(:info, message)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "No se pudo actualizar el estado")}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Profesional invalido")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="text-2xl font-bold">Gestion del Staff</h2>
            <p class="text-sm text-base-content/70">
              Alta tecnica de profesionales y control de estado activo/inactivo.
            </p>
          </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-[2fr_1fr]">
          <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
            <h3 class="mb-4 text-lg font-semibold">Staff Profesional</h3>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Nombre</th>
                    <th>Email</th>
                    <th>Rol</th>
                    <th>Estado</th>
                    <th class="text-right">Accion</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={user <- @staff}>
                    <td>{staff_name(user)}</td>
                    <td>{user.email}</td>
                    <td>{role_label(user.role)}</td>
                    <td>
                      <span class={
                        if user.is_active, do: "badge badge-success", else: "badge badge-warning"
                      }>
                        {if user.is_active, do: "Activo", else: "Inactivo"}
                      </span>
                    </td>
                    <td class="text-right">
                      <button
                        type="button"
                        class={[
                          "btn btn-xs",
                          if(user.is_active, do: "btn-soft btn-warning", else: "btn-soft btn-success")
                        ]}
                        phx-click="toggle_active"
                        phx-value-id={user.id}
                      >
                        {if user.is_active, do: "Marcar inactivo", else: "Reactivar"}
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
            <h3 class="mb-4 text-lg font-semibold">Nuevo Profesional</h3>

            <.form
              for={@form}
              id="new-professional-form"
              phx-submit="save_professional"
              class="space-y-2"
            >
              <.input field={@form[:university_id]} type="text" label="Legajo" required />
              <.input field={@form[:email]} type="email" label="Email" required />
              <.input field={@form[:first_name]} type="text" label="Nombre" />
              <.input field={@form[:last_name]} type="text" label="Apellido" />
              <.input field={@form[:role]} type="select" label="Rol" options={@roles} required />

              <button type="submit" class="btn btn-primary w-full">Nuevo Profesional</button>
            </.form>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp load_staff do
    ["psychologist", "psychiatrist", "psychopedagogue"]
    |> Enum.flat_map(&Accounts.list_users_by_role/1)
    |> Enum.sort_by(fn user ->
      {
        user.role,
        user.last_name || "",
        user.first_name || "",
        user.email || ""
      }
    end)
  end

  defp professional_form do
    to_form(
      %{
        "university_id" => "",
        "email" => "",
        "first_name" => "",
        "last_name" => "",
        "role" => "psychologist"
      },
      as: :professional
    )
  end

  defp professional_role?(role), do: role in ["psychologist", "psychiatrist", "psychopedagogue"]

  defp staff_name(user) do
    first = user.first_name || ""
    last = user.last_name || ""

    case String.trim("#{first} #{last}") do
      "" -> user.email
      full_name -> full_name
    end
  end

  defp role_label("psychologist"), do: "Psicologo"
  defp role_label("psychiatrist"), do: "Psiquiatra"
  defp role_label("psychopedagogue"), do: "Psicopedagogo"
  defp role_label(other), do: other

  defp first_error(changeset) do
    changeset.errors
    |> List.first()
    |> case do
      nil -> nil
      {_field, {message, _opts}} -> message
    end
  end
end
