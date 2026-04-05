defmodule CaeWeb.Clinic.ScheduleLive do
  use CaeWeb, :live_view

  alias Cae.Scheduling
  alias Cae.Accounts

  @weekday_options [
    {"Lunes", "1"},
    {"Martes", "2"},
    {"Miercoles", "3"},
    {"Jueves", "4"},
    {"Viernes", "5"},
    {"Sabado", "6"},
    {"Domingo", "7"}
  ]

  @repeat_options [
    {"1 semana", "1"},
    {"4 semanas", "4"},
    {"8 semanas", "8"},
    {"16 semanas", "16"}
  ]

  @session_options [
    {"20 minutos", "20"},
    {"30 minutos", "30"},
    {"45 minutos", "45"},
    {"60 minutos", "60"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    professional = current_professional(socket.assigns[:current_scope])
    appointments = list_professional_appointments(professional)

    socket =
      socket
      |> assign(:page_title, "Mi Agenda")
      |> assign(:current_scope, socket.assigns[:current_scope])
      |> assign(:professional, professional)
      |> assign(:appointments, appointments)
      |> assign(:calendar_events, build_calendar_events(appointments))
      |> assign(:weekday_options, @weekday_options)
      |> assign(:repeat_options, @repeat_options)
      |> assign(:session_options, @session_options)
      |> assign(:form, availability_form())

    {:ok, socket}
  end

  @impl true
  def handle_event("create_availability", %{"availability" => params}, socket) do
    professional = socket.assigns.professional

    if professional do
      case Scheduling.create_recurring_availability(
             professional.id,
             params["weekday"],
             params["start_time"],
             params["end_time"],
             params["duration_minutes"],
             params["repeat_weeks"]
           ) do
        {:ok, inserted} ->
          appointments = list_professional_appointments(professional)
          events = build_calendar_events(appointments)

          {:noreply,
           socket
           |> assign(:appointments, appointments)
           |> assign(:calendar_events, events)
           |> assign(:form, availability_form())
           |> push_event("schedule:events", %{events: events})
           |> put_flash(:info, "Disponibilidades creadas: #{inserted}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, error_message(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay profesional autenticado")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 class="text-2xl font-bold">Mi Agenda</h2>
            <p class="text-sm text-base-content/70">
              Gestiona disponibilidad recurrente por bloques semanales.
            </p>
          </div>

          <button
            type="button"
            class="btn btn-primary"
            aria-haspopup="dialog"
            aria-expanded="false"
            aria-controls="create-availability-modal"
            data-overlay="#create-availability-modal"
          >
            Crear Disponibilidad
          </button>
        </div>

        <div
          id="clinic-schedule-calendar-wrapper"
          phx-update="ignore"
          class="rounded-box border border-base-content/10 bg-base-100 p-4"
        >
          <div
            id="clinic-schedule-calendar"
            phx-hook="ClinicScheduleCalendar"
            data-events={Jason.encode!(@calendar_events)}
            class="min-h-96"
          >
          </div>
        </div>

        <div class="overflow-x-auto rounded-box border border-base-content/10 bg-base-100">
          <table class="table">
            <thead>
              <tr>
                <th>Inicio</th>
                <th>Fin</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={appointment <- @appointments}>
                <td>{format_datetime(appointment.start_at)}</td>
                <td>{format_datetime(appointment.end_at)}</td>
                <td>
                  <span class={status_badge_class(appointment.status)}>{appointment.status}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <div
        id="create-availability-modal"
        class="overlay modal overlay-open:opacity-100 overlay-open:duration-300 hidden"
        role="dialog"
        tabindex="-1"
      >
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-header">
              <h3 class="modal-title">Crear Disponibilidad Recurrente</h3>
              <button
                type="button"
                class="btn btn-text btn-circle btn-sm absolute end-3 top-3"
                aria-label="Close"
                data-overlay="#create-availability-modal"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>

            <.form for={@form} id="create-availability-form" phx-submit="create_availability">
              <div class="modal-body space-y-3">
                <.input
                  field={@form[:weekday]}
                  type="select"
                  label="Dia de la semana"
                  options={@weekday_options}
                />
                <.input field={@form[:start_time]} type="time" label="Hora de inicio" />
                <.input field={@form[:end_time]} type="time" label="Hora de fin" />

                <.input
                  field={@form[:duration_minutes]}
                  type="select"
                  label="Duracion de sesion"
                  options={@session_options}
                />

                <.input
                  field={@form[:repeat_weeks]}
                  type="select"
                  label="Repetir por"
                  options={@repeat_options}
                />
              </div>

              <div class="modal-footer">
                <button
                  type="button"
                  class="btn btn-soft btn-secondary"
                  data-overlay="#create-availability-modal"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="btn btn-primary"
                  data-overlay="#create-availability-modal"
                >
                  Guardar
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp availability_form do
    to_form(
      %{
        "weekday" => "1",
        "start_time" => "08:00",
        "end_time" => "12:00",
        "duration_minutes" => "30",
        "repeat_weeks" => "4"
      },
      as: :availability
    )
  end

  defp current_professional(nil), do: Accounts.list_users_by_role("psychologist") |> List.first()

  defp current_professional(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) ->
        Accounts.get_user!(Map.get(user, :id))

      is_map(user) and is_integer(Map.get(user, "id")) ->
        Accounts.get_user!(Map.get(user, "id"))

      true ->
        Accounts.list_users_by_role("psychologist") |> List.first()
    end
  end

  defp list_professional_appointments(nil), do: []

  defp list_professional_appointments(professional) do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 120)
    Scheduling.list_professional_appointments(professional.id, start_date, end_date)
  end

  defp build_calendar_events(appointments) do
    Enum.map(appointments, fn appointment ->
      %{
        id: appointment.id,
        title: calendar_title(appointment),
        start: DateTime.to_iso8601(appointment.start_at),
        end: DateTime.to_iso8601(appointment.end_at)
      }
    end)
  end

  defp calendar_title(%{status: "booked"}), do: "Reservado"
  defp calendar_title(%{status: "blocked"}), do: "Bloqueado"
  defp calendar_title(_), do: "Disponible"

  defp status_badge_class("available"), do: "badge badge-success"
  defp status_badge_class("booked"), do: "badge badge-primary"
  defp status_badge_class("blocked"), do: "badge badge-warning"
  defp status_badge_class("cancelled"), do: "badge badge-error"
  defp status_badge_class(_), do: "badge"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  end

  defp error_message(:invalid_weekday), do: "Dia de semana invalido"
  defp error_message(:invalid_duration), do: "Duracion invalida"
  defp error_message(:invalid_repeat_weeks), do: "Repeticion invalida"
  defp error_message(:invalid_time), do: "Formato de hora invalido"
  defp error_message(:invalid_time_range), do: "La hora de fin debe ser mayor que la de inicio"
  defp error_message(:professional_not_found), do: "Profesional no encontrado"
  defp error_message(:not_professional), do: "El usuario no es un profesional valido"
  defp error_message(_), do: "No se pudo crear la disponibilidad"
end
