defmodule CaeWeb.Clinic.PatientsLive do
  use CaeWeb, :live_view

  alias Cae.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    students = Accounts.list_students("")

    {:ok,
     socket
     |> assign(:page_title, "Buscador de Pacientes")
     |> assign(:current_scope, current_scope)
     |> assign(:search_query, "")
     |> assign(:patients_empty?, Enum.empty?(students))
     |> stream(:patients, students)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    students = Accounts.list_students(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:patients_empty?, Enum.empty?(students))
     |> stream(:patients, students, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <%!-- Header --%>
        <div class="flex flex-col gap-2">
          <h2 class="text-3xl font-bold tracking-tight">Buscador de Pacientes</h2>
          <p class="text-sm text-base-content/70">
            Busca y accede al Dashboard 360 de cada alumno
          </p>
        </div>

        <%!-- Search Form --%>
        <div class="card border border-base-content/10 bg-base-100 shadow-sm">
          <div class="card-body p-4">
            <form phx-change="search" phx-submit="search" class="flex gap-2">
              <label class="input input-bordered flex items-center gap-2 flex-1">
                <span class="icon-[tabler--search] size-5 text-base-content/40"></span>
                <input
                  type="search"
                  name="search"
                  placeholder="Busca por nombre, apellido o legajo..."
                  class="grow"
                  value={@search_query}
                  phx-debounce="300"
                />
              </label>
            </form>
          </div>
        </div>

        <%!-- Patients Table --%>
        <div class="card border border-base-content/10 bg-base-100 shadow-sm">
          <div class="card-body p-0">
            <div class="w-full overflow-x-auto">
              <table class="table row-hover">
                <thead>
                  <tr>
                    <th class="bg-base-200/50">Paciente</th>
                    <th class="bg-base-200/50">Legajo</th>
                    <th class="bg-base-200/50">Carrera</th>
                    <th class="bg-base-200/50">Estado</th>
                    <th class="bg-base-200/50">Acciones</th>
                  </tr>
                </thead>
                <tbody id="patients" phx-update="stream">
                  <tr :for={{id, patient} <- @streams.patients} id={id} class="row-hover">
                    <td>
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="w-8 rounded-full bg-primary/20 text-primary">
                            <span class="text-sm font-semibold">{get_avatar_initials(patient)}</span>
                          </div>
                        </div>
                        <div>
                          <div class="font-semibold text-sm">
                            {patient.first_name} {patient.last_name}
                          </div>
                          <div class="text-xs text-base-content/60">
                            {patient.email}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="text-sm">
                      <span class="font-mono font-semibold text-base-content/70">
                        {get_file_number(patient)}
                      </span>
                    </td>
                    <td class="text-sm">
                      {get_career(patient)}
                    </td>
                    <td>
                      <span class="badge badge-soft badge-success text-xs">
                        Activo
                      </span>
                    </td>
                    <td class="text-center">
                      <.link
                        navigate={~p"/live/clinic/patients/#{patient.id}"}
                        class="btn btn-sm btn-primary"
                        aria-label="Ver perfil del paciente"
                      >
                        <.icon name="hero-eye" class="size-4" />
                        <span class="hidden sm:inline">Ver</span>
                      </.link>
                    </td>
                  </tr>
                </tbody>
              </table>

              <%!-- Empty state --%>
              <div :if={@patients_empty?} class="p-8 text-center">
                <div class="flex flex-col items-center gap-4">
                  <span class="icon-[tabler--search-off] size-12 text-base-content/30"></span>
                  <div>
                    <p class="font-semibold text-base-content/70">
                      Ningún paciente encontrado
                    </p>
                    <p class="text-sm text-base-content/50">
                      Intenta con otro nombre, apellido o legajo
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # Helper functions
  defp get_avatar_initials(patient) do
    first = patient.first_name || ""
    last = patient.last_name || ""

    (String.first(first) || "") <> (String.first(last) || "")
  end

  defp get_file_number(patient) do
    if patient.student_profile do
      patient.student_profile.file_number || "-"
    else
      "-"
    end
  end

  defp get_career(patient) do
    if patient.student_profile do
      patient.student_profile.career || "Sin carrera"
    else
      "Sin carrera"
    end
  end
end
