defmodule CaeWeb.Clinic.ScheduleLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @recurrence_options [
    {"Solo por hoy", "none"},
    {"Repeat every week on this day", "weekly"},
    {"Repeat for a month", "monthly"},
    {"Repeat for a semester", "semester"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    professional = current_professional(socket.assigns[:current_scope])
    appointments = load_appointments(professional)

    {:ok,
     socket
     |> assign(:page_title, "Mi Agenda")
     |> assign(:current_scope, socket.assigns[:current_scope])
     |> assign(:professional, professional)
     |> assign(:appointments, appointments)
     |> assign(:calendar_events, build_calendar_events(appointments))
     |> assign(:recurrence_options, @recurrence_options)
     |> assign(:show_modal, false)
     |> assign(:start_date, nil)
     |> assign(:end_date, nil)
     |> assign(:availability_modal_title, "Crear disponibilidad")
     |> assign(:form, availability_form())}
  end

  @impl true
  def handle_event("create_availability", %{"availability" => params}, socket) do
    professional = socket.assigns.professional

    case Scheduling.create_availability(professional.id, params) do
      {:ok, _availability} ->
        appointments = load_appointments(professional)
        events = build_calendar_events(appointments)

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:calendar_events, events)
         |> assign(:show_modal, false)
         |> assign(:start_date, nil)
         |> assign(:end_date, nil)
         |> assign(:availability_modal_title, "Crear disponibilidad")
         |> assign(:form, availability_form())
         |> push_event("update_events", %{events: events})
         |> put_flash(:info, "Disponibilidad guardada con éxito.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :availability))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  @impl true
  def handle_event("prepare_slot", %{"start" => start_at, "end" => end_at}, socket) do
    {form, title} = availability_form_for_slot(start_at, end_at)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:start_date, start_at)
     |> assign(:end_date, end_at)
     |> assign(:availability_modal_title, title)
     |> assign(:show_modal, true)}
  end

  @impl true
  def handle_event("open_availability_modal", _params, socket) do
    {form, title} = availability_form_for_slot(nil, nil)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:start_date, nil)
     |> assign(:end_date, nil)
     |> assign(:availability_modal_title, title)
     |> assign(:show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:start_date, nil)
     |> assign(:end_date, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h2 class="text-2xl font-bold">Availability & Appointment Manager</h2>
            <p class="text-sm text-base-content/70">
              Mes por defecto, drill-down a dia y alta de disponibilidad recurrente.
            </p>
          </div>

          <button
            type="button"
            class="btn btn-primary"
            phx-click="open_availability_modal"
          >
            Crear Disponibilidad
          </button>
        </div>

        <div class="card flex not-prose w-full p-4 shadow-sm">
          <div id="calendar-custom-wrapper" phx-update="ignore" class="w-full">
            <div
              id="calendar-custom"
              phx-hook="AvailabilityManager"
              data-events={Jason.encode!(@calendar_events)}
              class="min-h-[38rem] w-full"
            >
            </div>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-3">
          <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
            <p class="text-sm text-base-content/70">Booked Appointments</p>
            <p class="text-2xl font-bold">{Enum.count(@appointments, &(&1.status == "booked"))}</p>
          </div>

          <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
            <p class="text-sm text-base-content/70">Available Blocks</p>
            <p class="text-2xl font-bold">{Enum.count(@appointments, &(&1.status == "available"))}</p>
          </div>

          <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
            <p class="text-sm text-base-content/70">Upcoming Blocks</p>
            <p class="text-2xl font-bold">{length(@appointments)}</p>
          </div>
        </div>
      </section>

      <.modal
        :if={@show_modal}
        id="availability-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">{@availability_modal_title}</h3>
              <p class="text-sm text-base-content/70">
                Configura horario y recurrencia.
              </p>
            </div>

            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="close_modal"
              aria-label="Cerrar"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <.form for={@form} id="availability-form" phx-submit="create_availability" class="space-y-4">
            <div class="grid gap-4 md:grid-cols-2">
              <div class="space-y-2">
                <label for="availabilityStartTime" class="block text-sm font-medium text-base-content">
                  Hora de inicio
                </label>
                <div class="relative">
                  <div class="pointer-events-none absolute inset-y-0 end-0 flex items-center pe-3 text-base-content/50">
                    <.icon name="hero-clock" class="size-4" />
                  </div>
                  <input
                    type="time"
                    id="availabilityStartTime"
                    name={@form[:start_time].name}
                    value={@form[:start_time].value}
                    required
                    class="input input-bordered w-full pe-10"
                  />
                </div>
              </div>

              <div class="space-y-2">
                <label for="availabilityEndTime" class="block text-sm font-medium text-base-content">
                  Hora de fin
                </label>
                <div class="relative">
                  <div class="pointer-events-none absolute inset-y-0 end-0 flex items-center pe-3 text-base-content/50">
                    <.icon name="hero-clock" class="size-4" />
                  </div>
                  <input
                    type="time"
                    id="availabilityEndTime"
                    name={@form[:end_time].name}
                    value={@form[:end_time].value}
                    required
                    class="input input-bordered w-full pe-10"
                  />
                </div>
              </div>
            </div>

            <.input
              field={@form[:recurrence]}
              id="availabilityRecurrence"
              type="select"
              label="Recurrencia"
              options={@recurrence_options}
              required
            />

            <.input field={@form[:weekday]} type="hidden" id="availability_weekday" />
            <.input field={@form[:availability_date]} type="hidden" id="availability_date" />

            <div class="flex justify-end gap-3 pt-2">
              <button type="button" class="btn btn-soft" phx-click="close_modal">Cancelar</button>
              <button type="submit" class="btn btn-primary">Guardar disponibilidad</button>
            </div>
          </.form>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp availability_form(attrs \\ %{}) do
    base = %{
      "weekday" => "1",
      "availability_date" => Date.to_iso8601(Date.utc_today()),
      "start_time" => "08:00",
      "end_time" => "12:00",
      "recurrence" => "none"
    }

    to_form(
      Map.merge(base, attrs),
      as: :availability
    )
  end

  defp availability_form_for_slot(start_iso, end_iso) do
    start_dt = parse_slot_datetime(start_iso) || DateTime.utc_now()
    end_dt = parse_slot_datetime(end_iso) || DateTime.add(start_dt, 3600, :second)

    end_dt =
      if DateTime.compare(end_dt, start_dt) == :gt do
        end_dt
      else
        DateTime.add(start_dt, 3600, :second)
      end

    form =
      availability_form(%{
        "weekday" => start_dt |> DateTime.to_date() |> Date.day_of_week() |> Integer.to_string(),
        "availability_date" => start_dt |> DateTime.to_date() |> Date.to_iso8601(),
        "start_time" => Calendar.strftime(start_dt, "%H:%M"),
        "end_time" => Calendar.strftime(end_dt, "%H:%M")
      })

    title = "Crear disponibilidad - #{Calendar.strftime(start_dt, "%d/%m/%Y")}"
    {form, title}
  end

  defp parse_slot_datetime(nil), do: nil

  defp parse_slot_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp current_professional(nil), do: Accounts.list_users_by_role("psychologist") |> List.first()

  defp current_professional(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> Accounts.get_user!(Map.get(user, :id))
      is_map(user) and is_integer(Map.get(user, "id")) -> Accounts.get_user!(Map.get(user, "id"))
      true -> Accounts.list_users_by_role("psychologist") |> List.first()
    end
  end

  defp load_appointments(nil), do: []

  defp load_appointments(professional) do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 120)
    Scheduling.list_professional_appointments(professional.id, start_date, end_date)
  end

  defp build_calendar_events(appointments) do
    Enum.map(appointments, fn appointment ->
      %{
        id: appointment.id,
        title: event_title(appointment),
        start: DateTime.to_iso8601(appointment.start_at),
        end: DateTime.to_iso8601(appointment.end_at),
        classNames: [event_class(appointment.status)],
        extendedProps: %{status: appointment.status}
      }
    end)
  end

  defp event_title(%{status: "available"}), do: "Available Block"

  defp event_title(%{status: "booked", student: %{first_name: first, last_name: last}}),
    do: "Booked - #{first} #{last}"

  defp event_title(%{status: "booked"}), do: "Booked Appointment"
  defp event_title(_), do: "Appointment"

  defp event_class("available"), do: "fc-event-success"
  defp event_class("booked"), do: "fc-event-primary"
  defp event_class("blocked"), do: "fc-event-warning"
  defp event_class("cancelled"), do: "fc-event-error"
  defp event_class(_), do: "fc-event-info"

  defp format_error(:professional_not_found), do: "Profesional no encontrado"
  defp format_error(:not_professional), do: "El usuario no es un profesional valido"
  defp format_error(:invalid_weekday), do: "Dia de semana invalido"
  defp format_error(:invalid_duration), do: "Duracion invalida"
  defp format_error(:invalid_gap), do: "Gap invalido"
  defp format_error(:invalid_repeat_weeks), do: "Recurrencia invalida"
  defp format_error(:invalid_time), do: "Formato de hora invalido"

  defp format_error(:invalid_time_range),
    do: "La hora de fin debe ser posterior a la hora de inicio"

  defp format_error(_), do: "No se pudo crear la disponibilidad"
end
