defmodule CaeWeb.Secretary.StudentsLive do
  use CaeWeb, :live_view

  alias Cae.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    students = Accounts.list_students("")

    {:ok,
     socket
     |> assign(:page_title, "Directorio de Pacientes")
     |> assign(:current_scope, current_scope)
     |> assign(:search_query, "")
     |> assign(:students_empty?, Enum.empty?(students))
     |> stream(:students, students)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    students = Accounts.list_students(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:students_empty?, Enum.empty?(students))
     |> stream(:students, students, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-col gap-2">
          <h2 class="text-3xl font-bold tracking-tight">Directorio de Pacientes</h2>
          <p class="text-sm text-base-content/70">
            Busca alumnos y navega rápido a sus pantallas de gestión.
          </p>
        </div>

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

        <div class="card border border-base-content/10 bg-base-100 shadow-sm">
          <div class="card-body p-0">
            <div class="w-full overflow-x-auto">
              <table class="table row-hover table-pin-rows">
                <thead>
                  <tr>
                    <th class="bg-base-200/50">Nombre</th>
                    <th class="bg-base-200/50">Legajo</th>
                    <th class="bg-base-200/50">Carrera</th>
                    <th class="bg-base-200/50">Teléfono</th>
                    <th class="bg-base-200/50 !text-center">Acciones</th>
                  </tr>
                </thead>
                <tbody id="students" phx-update="stream">
                  <tr :for={{id, student} <- @streams.students} id={id} class="row-hover">
                    <td>
                      <div class="font-semibold text-sm">{student_full_name(student)}</div>
                      <div class="text-xs text-base-content/60">{student.email}</div>
                    </td>

                    <td class="text-sm">
                      <span class="font-mono font-semibold text-base-content/70">
                        {student_file_number(student)}
                      </span>
                    </td>

                    <td class="text-sm">{student_career(student)}</td>

                    <td class="text-sm">{student_phone(student)}</td>

                    <td class="!text-center">
                      <div class="flex items-center justify-center gap-1">
                        <.link
                          navigate={~p"/live/secretary/students/#{student.id}/appointments"}
                          class="btn btn-circle btn-text btn-sm hover:bg-primary/10 hover:text-primary"
                          aria-label="Ver turnos"
                          title="Ver Turnos"
                        >
                          <.icon name="hero-calendar-days" class="size-5" />
                        </.link>

                        <.link
                          navigate={~p"/live/clinic/patients/#{student.id}/schedule"}
                          class="btn btn-circle btn-text btn-sm hover:bg-primary/10 hover:text-primary"
                          aria-label="Sacar turno"
                          title="Sacar Turno"
                        >
                          <.icon name="hero-plus-circle" class="size-5" />
                        </.link>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>

              <div :if={@students_empty?} class="p-8 text-center">
                <div class="flex flex-col items-center gap-4">
                  <span class="icon-[tabler--search-off] size-12 text-base-content/30"></span>
                  <div>
                    <p class="font-semibold text-base-content/70">Ningún alumno encontrado</p>
                    <p class="text-sm text-base-content/50">
                      Intenta con otro nombre, apellido o legajo.
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

  defp student_full_name(student) do
    cond do
      is_binary(student.first_name) and is_binary(student.last_name) ->
        "#{student.first_name} #{student.last_name}"

      is_binary(student.email) ->
        student.email

      true ->
        "Alumno"
    end
  end

  defp student_file_number(student) do
    profile = Map.get(student, :student_profile)
    if profile, do: profile.file_number || "-", else: "-"
  end

  defp student_career(student) do
    profile = Map.get(student, :student_profile)
    if profile, do: profile.career || "Sin carrera", else: "Sin carrera"
  end

  defp student_phone(student) do
    profile = Map.get(student, :student_profile)
    if profile, do: profile.emergency_contact_phone || "-", else: "-"
  end
end
