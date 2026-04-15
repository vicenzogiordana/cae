defmodule CaeWeb.Secretary.StudentAppointmentsLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling

  @impl true
  def mount(%{"student_id" => student_id}, _session, socket) do
    with {:ok, parsed_student_id} <- parse_id(student_id),
         %Accounts.User{} = student <- Accounts.get_user_by(id: parsed_student_id),
         true <- student.role == "student" do
      appointments = Scheduling.list_student_appointments(student.id)
      {upcoming, past} = split_appointments(appointments)

      {:ok,
       socket
       |> assign(:page_title, "Turnos del Alumno")
       |> assign(:current_scope, socket.assigns[:current_scope])
       |> assign(:student, student)
       |> assign(:upcoming_appointments, upcoming)
       |> assign(:past_appointments, past)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "No se encontró el alumno solicitado")
         |> push_navigate(to: ~p"/live/secretary/students")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h2 class="text-2xl font-bold">Turnos del Alumno</h2>
            <p class="text-sm text-base-content/70">
              {student_name(@student)}
            </p>
          </div>

          <.link navigate={~p"/live/secretary/students"} class="btn btn-soft btn-secondary btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Volver al directorio
          </.link>
        </div>

        <section class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Próximos turnos</h3>
            <span class="badge badge-soft badge-primary">{length(@upcoming_appointments)}</span>
          </div>

          <div
            :if={Enum.empty?(@upcoming_appointments)}
            class="alert alert-soft alert-info"
            role="alert"
          >
            <span>El alumno no tiene turnos pendientes.</span>
          </div>

          <div
            :if={not Enum.empty?(@upcoming_appointments)}
            class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={appointment <- @upcoming_appointments}
              class="card border border-base-content/10 bg-base-100 shadow-sm"
            >
              <div class="card-body gap-2">
                <p class="text-sm font-semibold">{professional_name(appointment)}</p>
                <p class="text-sm text-base-content/70">
                  {format_date(appointment.start_at)}
                </p>
                <p class="text-sm text-base-content/70">
                  {format_time(appointment.start_at)} - {format_time(appointment.end_at)}
                </p>
              </div>
            </article>
          </div>
        </section>

        <section class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Historial</h3>
            <span class="badge badge-ghost">{length(@past_appointments)}</span>
          </div>

          <div :if={Enum.empty?(@past_appointments)} class="alert alert-soft" role="alert">
            <span>No hay turnos previos para este alumno.</span>
          </div>

          <div
            :if={not Enum.empty?(@past_appointments)}
            class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={appointment <- @past_appointments}
              class="card border border-base-content/10 bg-base-100/80 shadow-sm"
            >
              <div class="card-body gap-2">
                <p class="text-sm font-semibold">{professional_name(appointment)}</p>
                <p class="text-sm text-base-content/70">
                  {format_date(appointment.start_at)}
                </p>
                <p class="text-sm text-base-content/70">
                  {format_time(appointment.start_at)} - {format_time(appointment.end_at)}
                </p>
              </div>
            </article>
          </div>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp split_appointments(appointments) do
    now = DateTime.utc_now()

    Enum.split_with(appointments, fn appointment ->
      DateTime.compare(appointment.start_at, now) in [:gt, :eq]
    end)
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp parse_id(_), do: {:error, :invalid_id}

  defp student_name(student) do
    cond do
      is_binary(student.first_name) and is_binary(student.last_name) ->
        "#{student.first_name} #{student.last_name}"

      is_binary(student.email) ->
        student.email

      true ->
        "Alumno"
    end
  end

  defp professional_name(%{professional: professional}) when is_map(professional) do
    cond do
      is_binary(professional.first_name) and is_binary(professional.last_name) ->
        "#{professional.first_name} #{professional.last_name}"

      is_binary(professional.email) ->
        professional.email

      true ->
        "Profesional"
    end
  end

  defp professional_name(_), do: "Profesional"

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
