defmodule CaeWeb.Student.DashboardLive do
  use CaeWeb, :live_view

  alias Cae.Scheduling

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    student_id = current_student_id(current_scope)
    student_name = current_student_name(current_scope)

    upcoming_reminder =
      case student_id do
        {:ok, id} -> Scheduling.get_upcoming_reminder(id)
        :error -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Inicio")
     |> assign(:current_scope, current_scope)
     |> assign(:student_name, student_name)
     |> assign(:upcoming_reminder, upcoming_reminder)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-5 p-4 sm:p-6">
        <div class="space-y-1">
          <p class="text-sm text-base-content/60">Inicio</p>
          <h2 class="text-2xl font-bold tracking-tight">Hola, {@student_name}</h2>
        </div>

        <div
          :if={@upcoming_reminder}
          class="alert alert-soft alert-primary flex items-start gap-3"
          role="alert"
        >
          <.icon name="hero-bell-alert" class="mt-0.5 size-5 shrink-0" />
          <div class="space-y-1 text-sm">
            <p class="font-semibold">Próximo turno</p>
            <p>
              {format_reminder_day(@upcoming_reminder.start_at)} a las {format_time(
                @upcoming_reminder.start_at
              )} con {professional_name(@upcoming_reminder)}.
            </p>
          </div>
        </div>

        <div class="space-y-3">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
            Accesos rápidos
          </h3>

          <div class="grid grid-cols-2 gap-3">
            <.link
              navigate={~p"/live/student/book-appointment"}
              class="card border border-primary/30 bg-primary/10 shadow-sm transition hover:-translate-y-0.5 hover:shadow"
            >
              <div class="card-body gap-2 p-4">
                <.icon name="hero-calendar-days" class="size-6 text-primary" />
                <p class="text-sm font-semibold">Sacar Turno</p>
              </div>
            </.link>

            <.link
              navigate={~p"/live/student/appointments"}
              class="card border border-base-content/10 bg-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow"
            >
              <div class="card-body gap-2 p-4">
                <.icon name="hero-clipboard-document-list" class="size-6 text-primary" />
                <p class="text-sm font-semibold">Mis Turnos</p>
              </div>
            </.link>

            <.link
              href="#"
              class="card border border-base-content/10 bg-base-100 shadow-sm transition hover:-translate-y-0.5 hover:shadow"
            >
              <div class="card-body gap-2 p-4">
                <.icon name="hero-user-circle" class="size-6 text-primary" />
                <p class="text-sm font-semibold">Mi Perfil</p>
              </div>
            </.link>
          </div>
        </div>

        <div class="alert bg-base-200 text-base-content" role="alert">
          <.icon name="hero-information-circle" class="size-5 shrink-0" />
          <p class="text-sm leading-relaxed">
            Recordatorio: La autogestión de turnos es exclusiva para el área de Psicología. Para
            consultas de Psiquiatría o Psicopedagogía, debes ser derivado por tu profesional
            tratante o contactar a Secretaría.
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp current_student_id(current_scope) when is_map(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> {:ok, Map.get(user, :id)}
      is_map(user) and is_integer(Map.get(user, "id")) -> {:ok, Map.get(user, "id")}
      true -> :error
    end
  end

  defp current_student_id(_), do: :error

  defp current_student_name(current_scope) when is_map(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user") || %{}

    first_name = Map.get(user, :first_name) || Map.get(user, "first_name") || ""
    last_name = Map.get(user, :last_name) || Map.get(user, "last_name") || ""

    full_name = "#{first_name} #{last_name}" |> String.trim()
    if full_name == "", do: "Alumno", else: full_name
  end

  defp current_student_name(_), do: "Alumno"

  defp professional_name(appointment) do
    professional = Map.get(appointment, :professional)
    first_name = professional && Map.get(professional, :first_name)
    last_name = professional && Map.get(professional, :last_name)
    name = [first_name, last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.trim()
    if name == "", do: "Profesional", else: name
  end

  defp format_reminder_day(datetime) do
    date = DateTime.to_date(datetime)

    weekday =
      case Date.day_of_week(date) do
        1 -> "Lunes"
        2 -> "Martes"
        3 -> "Miércoles"
        4 -> "Jueves"
        5 -> "Viernes"
        6 -> "Sábado"
        7 -> "Domingo"
      end

    "#{weekday} #{String.pad_leading(Integer.to_string(date.day), 2, "0")}/#{String.pad_leading(Integer.to_string(date.month), 2, "0")}"
  end

  defp format_time(datetime), do: Calendar.strftime(datetime, "%H:%M")
end
