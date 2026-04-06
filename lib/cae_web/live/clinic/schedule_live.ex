defmodule CaeWeb.Clinic.ScheduleLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @recurrence_options [
    {"Solo por hoy", "none"},
    {"Mismo horario por las proximas 2 semanas", "weekly"},
    {"Mismo horario por el resto del mes", "monthly"},
    {"Mismo horario por el resto del cuatrimestre", "semester"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    professional = current_professional(socket.assigns[:current_scope])
    appointments = load_appointments(professional)
    recently_released_ids = recently_released_appointment_ids(professional)

    {:ok,
     socket
     |> assign(:page_title, "Mi Agenda")
     |> assign(:current_scope, socket.assigns[:current_scope])
     |> assign(:professional, professional)
     |> assign(:appointments, appointments)
     |> assign(:recently_released_ids, recently_released_ids)
     |> assign(:calendar_events, build_calendar_events(appointments, recently_released_ids))
     |> assign(:recurrence_options, @recurrence_options)
     |> assign(:show_modal, false)
     |> assign(:show_appointment_details_modal, false)
     |> assign(:start_date, nil)
     |> assign(:end_date, nil)
     |> assign(:availability_modal_title, "Crear disponibilidad")
     |> assign(:selected_appointment, %{})
     |> assign(:form, availability_form())}
  end

  @impl true
  def handle_event("create_availability", %{"availability" => _params}, socket)
      when is_nil(socket.assigns.professional) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "No hay profesionales disponibles para guardar disponibilidad."
     )}
  end

  @impl true
  def handle_event("create_availability", %{"availability" => params}, socket) do
    professional = socket.assigns.professional

    case Scheduling.create_availability(professional.id, params) do
      {:ok, _availability} ->
        appointments = load_appointments(professional)
        recently_released_ids = recently_released_appointment_ids(professional)
        events = build_calendar_events(appointments, recently_released_ids)

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:recently_released_ids, recently_released_ids)
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
  def handle_event("open_availability_modal", _params, socket)
      when is_nil(socket.assigns.professional) do
    {:noreply,
     put_flash(socket, :error, "No hay profesionales disponibles para crear disponibilidad.")}
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
  def handle_event("delete_availability", _params, socket)
      when is_nil(socket.assigns.professional) do
    {:noreply,
     put_flash(socket, :error, "No hay profesionales disponibles para borrar disponibilidad.")}
  end

  @impl true
  def handle_event("delete_availability", %{"id" => id}, socket) do
    professional = socket.assigns.professional

    with {:ok, appointment_id} <- parse_appointment_id(id),
         appointment when not is_nil(appointment) <- Scheduling.get_appointment(appointment_id),
         true <- appointment.professional_id == professional.id,
         true <- appointment.status == "available",
         {:ok, _deleted} <- Scheduling.delete_appointment(appointment) do
      appointments = load_appointments(professional)
      recently_released_ids = recently_released_appointment_ids(professional)
      events = build_calendar_events(appointments, recently_released_ids)

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:recently_released_ids, recently_released_ids)
       |> assign(:calendar_events, events)
       |> push_event("update_events", %{events: events})
       |> put_flash(:info, "Disponibilidad borrada con exito.")}
    else
      {:error, :invalid_id} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar la disponibilidad.")}

      nil ->
        {:noreply, put_flash(socket, :error, "La disponibilidad no existe.")}

      false ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Solo se pueden borrar bloques disponibles del profesional actual."
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "No se pudo borrar la disponibilidad.")}
    end
  end

  @impl true
  def handle_event("open_event_details", %{"id" => _id}, socket)
      when is_nil(socket.assigns.professional) do
    {:noreply, put_flash(socket, :error, "No hay profesionales disponibles para ver el turno.")}
  end

  @impl true
  def handle_event("open_event_details", %{"id" => id}, socket) do
    professional = socket.assigns.professional

    with {:ok, appointment_id} <- parse_appointment_id(id),
         appointment when not is_nil(appointment) <- Scheduling.get_appointment(appointment_id),
         true <- appointment.professional_id == professional.id,
         true <- appointment.status == "booked" do
      {:noreply,
       socket
       |> assign(:selected_appointment, appointment_details(appointment))
       |> assign(:show_appointment_details_modal, true)}
    else
      {:error, :invalid_id} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar el turno.")}

      nil ->
        {:noreply, put_flash(socket, :error, "El turno no existe.")}

      false ->
        {:noreply, put_flash(socket, :error, "Solo podés ver turnos del profesional actual.")}

      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo abrir el turno.")}
    end
  end

  @impl true
  def handle_event("close_appointment_details_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_appointment_details_modal, false)
     |> assign(:selected_appointment, %{})}
  end

  @impl true
  def handle_event("cancel_professional_appointment", _params, socket)
      when is_nil(socket.assigns.professional) do
    {:noreply,
     put_flash(socket, :error, "No hay profesionales disponibles para cancelar turnos.")}
  end

  @impl true
  def handle_event("cancel_professional_appointment", %{"id" => id}, socket) do
    professional = socket.assigns.professional

    with {:ok, appointment_id} <- parse_appointment_id(id),
         appointment when not is_nil(appointment) <- Scheduling.get_appointment(appointment_id),
         true <- appointment.professional_id == professional.id,
         true <- appointment.status == "booked",
         {:ok, _cancelled} <-
           Scheduling.cancel_professional_appointment(professional.id, appointment.id) do
      appointments = load_appointments(professional)
      recently_released_ids = recently_released_appointment_ids(professional)
      events = build_calendar_events(appointments, recently_released_ids)

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:recently_released_ids, recently_released_ids)
       |> assign(:calendar_events, events)
       |> assign(:show_appointment_details_modal, false)
       |> assign(:selected_appointment, %{})
       |> push_event("update_events", %{events: events})
       |> put_flash(:info, "Consulta cancelada por el profesional")}
    else
      {:error, :invalid_id} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar el turno")}

      nil ->
        {:noreply, put_flash(socket, :error, "El turno no existe")}

      false ->
        {:noreply, put_flash(socket, :error, "Solo podés cancelar turnos reservados propios")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "No se pudo cancelar la consulta")}
    end
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
            <p class="text-xs text-base-content/60">
              En vista dia puedes hacer click sobre un bloque disponible para borrarlo.
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
          <div id="calendar-custom-wrapper" class="w-full">
            <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 w-full mb-3">
              <div class="flex items-center gap-2 shrink-0">
                <button
                  type="button"
                  class="btn btn-soft btn-circle"
                  id="calendar-nav-prev"
                  aria-label="Anterior"
                >
                  <.icon name="hero-chevron-left" class="size-5" />
                </button>
                <button
                  type="button"
                  class="btn btn-soft btn-circle"
                  id="calendar-nav-next"
                  aria-label="Siguiente"
                >
                  <.icon name="hero-chevron-right" class="size-5" />
                </button>
                <h3 id="calendar-title" class="text-3xl font-bold leading-tight">Agenda</h3>
              </div>

              <div class="w-full sm:w-auto">
                <div class="hidden sm:inline-flex join">
                  <button
                    type="button"
                    class="btn btn-soft join-item"
                    data-calendar-view="dayGridMonth"
                  >
                    Mes
                  </button>
                  <button
                    type="button"
                    class="btn btn-soft join-item"
                    data-calendar-view="timeGridWeek"
                  >
                    Semana
                  </button>
                  <button
                    type="button"
                    class="btn btn-soft join-item"
                    data-calendar-view="timeGridDay"
                  >
                    Día
                  </button>
                  <button
                    type="button"
                    class="btn btn-soft join-item"
                    data-calendar-view="listMonth"
                  >
                    Lista
                  </button>
                </div>

                <select
                  id="calendar-view-select"
                  class="block sm:hidden select select-bordered w-full"
                  aria-label="Cambiar vista"
                >
                  <option value="dayGridMonth">Mes</option>
                  <option value="timeGridWeek">Semana</option>
                  <option value="timeGridDay">Día</option>
                  <option value="listMonth">Lista</option>
                </select>
              </div>
            </div>

            <div class="w-full overflow-x-auto pb-4">
              <div class="min-w-[800px]">
                <div
                  id="calendar-custom"
                  phx-hook="AvailabilityManager"
                  phx-update="ignore"
                  data-events={Jason.encode!(@calendar_events)}
                  class="min-h-[38rem] w-full"
                >
                </div>
              </div>
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

            <.input
              field={@form[:availability_date]}
              id="availabilityDate"
              type="date"
              label="Día"
              required
              min={Date.to_iso8601(Date.utc_today())}
            />

            <div class="flex justify-end gap-3 pt-2">
              <button type="button" class="btn btn-soft" phx-click="close_modal">Cancelar</button>
              <button type="submit" class="btn btn-primary">Guardar disponibilidad</button>
            </div>
          </.form>
        </div>
      </.modal>

      <.modal
        :if={@show_appointment_details_modal}
        id="appointment-details-modal"
        show
        on_cancel={JS.push("close_appointment_details_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">Detalle del turno</h3>
              <p class="text-sm text-base-content/70">
                Información del alumno y el horario reservado.
              </p>
            </div>

            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="close_appointment_details_modal"
              aria-label="Cerrar"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <div class="space-y-4 rounded-box border border-base-content/10 bg-base-100 p-4">
            <div class="grid gap-4 md:grid-cols-2">
              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">Alumno</p>
                <p class="font-semibold">
                  {Map.get(@selected_appointment, :student_name) || "Sin alumno asignado"}
                </p>
              </div>

              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">Estado</p>
                <p class="font-semibold text-primary">
                  {Map.get(@selected_appointment, :status_label) || "Turno"}
                </p>
              </div>
            </div>

            <div>
              <p class="text-xs uppercase tracking-wide text-base-content/50">Profesional</p>
              <p class="font-medium">{Map.get(@selected_appointment, :professional_name)}</p>
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">Inicio</p>
                <p class="font-medium">{Map.get(@selected_appointment, :start_label)}</p>
              </div>

              <div>
                <p class="text-xs uppercase tracking-wide text-base-content/50">Fin</p>
                <p class="font-medium">{Map.get(@selected_appointment, :end_label)}</p>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-2">
              <button
                type="button"
                class="btn btn-soft"
                phx-click="close_appointment_details_modal"
              >
                Cerrar
              </button>
              <button
                type="button"
                class="btn btn-warning"
                phx-click="cancel_professional_appointment"
                phx-value-id={Map.get(@selected_appointment, :id)}
              >
                Cancelar consulta
              </button>
            </div>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp availability_form(attrs \\ %{}) do
    base = %{
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
    today = Date.utc_today() |> Date.to_iso8601()
    {:ok, start_date, start_time} = parse_slot_local(start_iso, today, "08:00")
    {:ok, _end_date, end_time} = parse_slot_local(end_iso, start_date, "09:00")

    form =
      availability_form(%{
        "availability_date" => start_date,
        "start_time" => start_time,
        "end_time" => end_time
      })

    title =
      case Date.from_iso8601(start_date) do
        {:ok, date} -> "Crear disponibilidad - #{Calendar.strftime(date, "%d/%m/%Y")}"
        _ -> "Crear disponibilidad"
      end

    {form, title}
  end

  defp parse_slot_local(value, fallback_date, fallback_time) when is_binary(value) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/, value) do
      [_, date, time] -> {:ok, date, time}
      _ -> {:ok, fallback_date, fallback_time}
    end
  end

  defp parse_slot_local(_, fallback_date, fallback_time), do: {:ok, fallback_date, fallback_time}

  defp current_professional(nil), do: first_available_professional()

  defp current_professional(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> Accounts.get_user!(Map.get(user, :id))
      is_map(user) and is_integer(Map.get(user, "id")) -> Accounts.get_user!(Map.get(user, "id"))
      true -> first_available_professional()
    end
  end

  defp first_available_professional do
    ["psychologist", "psychiatrist", "psychopedagogue"]
    |> Enum.find_value(fn role ->
      Accounts.list_users_by_role(role)
      |> List.first()
    end)
  end

  defp load_appointments(nil), do: []

  defp load_appointments(professional) do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 120)
    Scheduling.list_professional_appointments(professional.id, start_date, end_date)
  end

  defp recently_released_appointment_ids(nil), do: []

  defp recently_released_appointment_ids(professional) do
    Scheduling.list_recently_released_appointment_ids(professional.id, 24)
  end

  defp build_calendar_events(appointments, recently_released_ids) do
    Enum.map(appointments, fn appointment ->
      released_recently? = released_recently?(appointment, recently_released_ids)

      %{
        id: appointment.id,
        title: event_title(appointment, released_recently?),
        start: appointment.start_at |> DateTime.to_naive() |> NaiveDateTime.to_iso8601(),
        end: appointment.end_at |> DateTime.to_naive() |> NaiveDateTime.to_iso8601(),
        classNames: [event_class(appointment.status, released_recently?)],
        extendedProps: %{
          status: appointment.status,
          released_recently: released_recently?,
          student_name: booked_student_name(appointment),
          booked_by_name: booked_by_name(appointment)
        }
      }
    end)
  end

  defp event_title(%{status: "available"}, true), do: "Disponible (reabierto)"

  defp event_title(%{status: "available"}, false), do: "Available Block"

  defp event_title(%{status: "booked"}, _released_recently?), do: "Turno ocupado"

  defp event_title(%{status: "cancelled"}, _released_recently?), do: "Consulta cancelada"

  defp event_title(_appointment, _released_recently?), do: "Appointment"

  defp released_recently?(%{status: "available", id: appointment_id}, recently_released_ids) do
    appointment_id in recently_released_ids
  end

  defp released_recently?(_appointment, _recently_released_ids), do: false

  defp booked_student_name(%{status: "booked", student: %{first_name: first, last_name: last}}),
    do: Enum.join([first, last], " ")

  defp booked_student_name(_), do: nil

  defp booked_by_name(%{status: "booked", booked_by: %{first_name: first, last_name: last}}),
    do: Enum.join([first, last], " ")

  defp booked_by_name(_), do: nil

  defp appointment_details(appointment) do
    %{
      id: appointment.id,
      status: appointment.status,
      status_label: appointment_status_label(appointment.status),
      professional_name: professional_name(appointment.professional),
      student_name: booked_student_name(appointment),
      booked_by_name: booked_by_name(appointment),
      start_label: format_appointment_datetime(appointment.start_at),
      end_label: format_appointment_datetime(appointment.end_at)
    }
  end

  defp appointment_status_label("available"), do: "Disponible"
  defp appointment_status_label("booked"), do: "Turno ocupado"
  defp appointment_status_label("cancelled"), do: "Cancelado"
  defp appointment_status_label("blocked"), do: "Bloqueado"
  defp appointment_status_label(_), do: "Turno"

  defp professional_name(%{first_name: first, last_name: last}), do: Enum.join([first, last], " ")
  defp professional_name(_), do: "Sin profesional"

  defp format_appointment_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  defp format_appointment_datetime(_), do: "Sin fecha"

  defp event_class("available", true), do: "fc-event-warning"
  defp event_class("available", false), do: "fc-event-success"
  defp event_class("booked", _), do: "fc-event-primary"
  defp event_class("blocked", _), do: "fc-event-warning"
  defp event_class("cancelled", _), do: "fc-event-warning"
  defp event_class(_, _), do: "fc-event-info"

  defp parse_appointment_id(value) when is_integer(value), do: {:ok, value}

  defp parse_appointment_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_appointment_id(_), do: {:error, :invalid_id}
end
