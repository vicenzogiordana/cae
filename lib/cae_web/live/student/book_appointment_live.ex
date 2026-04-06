defmodule CaeWeb.Student.BookAppointmentLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    professionals = list_psychologists()
    selected_professional_id = nil
    appointments = load_available_appointments(selected_professional_id)
    events = build_calendar_events(appointments)

    socket =
      socket
      |> assign(:page_title, "Sacar Turno")
      |> assign(:current_scope, socket.assigns[:current_scope])
      |> assign(:professionals, professionals)
      |> assign(:selected_professional_id, selected_professional_id)
      |> assign(:appointments, appointments)
      |> assign(:calendar_events, events)
      |> assign(:show_modal, false)
      |> assign(:selected_slot, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_professional", %{"professional_id" => professional_id}, socket) do
    selected_professional_id = parse_optional_int(professional_id)
    appointments = load_available_appointments(selected_professional_id)
    events = build_calendar_events(appointments)

    {:noreply,
     socket
     |> assign(:selected_professional_id, selected_professional_id)
     |> assign(:appointments, appointments)
     |> assign(:calendar_events, events)
     |> push_event("refresh_events", %{events: events})}
  end

  @impl true
  def handle_event(
        "select_appointment_slot",
        %{"id" => id, "start" => start_at, "end" => end_at},
        socket
      ) do
    appointments = socket.assigns.appointments

    with {:ok, appointment_id} <- parse_appointment_id(id),
         appointment when not is_nil(appointment) <-
           find_appointment(appointments, appointment_id) do
      slot = %{
        id: appointment.id,
        professional_name: professional_name(appointment),
        start_label: format_slot_datetime(start_at, appointment.start_at),
        end_label: format_slot_datetime(end_at, appointment.end_at)
      }

      {:noreply,
       socket
       |> assign(:selected_slot, slot)
       |> assign(:show_modal, true)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo seleccionar el turno")}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:selected_slot, nil)}
  end

  @impl true
  def handle_event("confirm_booking", _params, socket) do
    selected_slot = socket.assigns.selected_slot
    appointment_id = selected_slot && selected_slot.id
    selected_professional_id = socket.assigns.selected_professional_id

    with true <- is_integer(appointment_id),
         {:ok, student_id} <- current_student_id(socket.assigns.current_scope),
         {:ok, _appointment} <-
           Scheduling.book_available_appointment_for_student(appointment_id, student_id) do
      appointments = load_available_appointments(selected_professional_id)
      events = build_calendar_events(appointments)

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:calendar_events, events)
       |> assign(:show_modal, false)
       |> assign(:selected_slot, nil)
       |> push_event("refresh_events", %{events: events})
       |> put_flash(:info, "Turno reservado correctamente")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Debe seleccionar un turno")}

      {:error, :student_not_found} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar al alumno actual")}

      {:error, :not_available} ->
        appointments = load_available_appointments(selected_professional_id)
        events = build_calendar_events(appointments)

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:calendar_events, events)
         |> assign(:show_modal, false)
         |> assign(:selected_slot, nil)
         |> push_event("refresh_events", %{events: events})
         |> put_flash(:error, "El turno ya no esta disponible")}

      {:error, :weekly_limit_reached} ->
        appointments = load_available_appointments(selected_professional_id)
        events = build_calendar_events(appointments)

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:calendar_events, events)
         |> assign(:show_modal, false)
         |> assign(:selected_slot, nil)
         |> push_event("refresh_events", %{events: events})
         |> put_flash(:error, "Ya tenes un turno reservado para esta semana")}

      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo reservar el turno")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div>
          <h2 class="text-2xl font-bold">Sacar Turno</h2>
          <p class="text-sm text-base-content/70">Elegí profesional, día y horario disponible.</p>
        </div>

        <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
          <form phx-change="filter_professional" class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <label class="form-control w-full sm:max-w-sm">
              <span class="label-text mb-2">Profesional</span>
              <select name="professional_id" class="select select-bordered w-full">
                <option value="">Todos los psicólogos</option>
                <option
                  :for={professional <- @professionals}
                  value={professional.id}
                  selected={to_string(@selected_professional_id || "") == to_string(professional.id)}
                >
                  {professional_name(professional)}
                </option>
              </select>
            </label>
          </form>
        </div>

        <div class="card flex not-prose w-full p-4 shadow-sm">
          <div id="booking-calendar-wrapper" class="w-full overflow-x-auto pb-4">
            <div class="min-w-[800px]">
              <div
                id="booking-calendar"
                phx-hook="BookingCalendarHook"
                phx-update="ignore"
                data-events={Jason.encode!(@calendar_events)}
                class="min-h-[38rem] w-full"
              >
              </div>
            </div>
          </div>
        </div>

        <div :if={Enum.empty?(@appointments)} class="alert alert-soft alert-info" role="alert">
          <span>No hay turnos disponibles para el filtro seleccionado.</span>
        </div>
      </section>

      <.modal
        :if={@show_modal}
        id="confirm-booking-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">Confirmar reserva</h3>
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

          <div class="rounded-box border border-base-content/10 bg-base-100 p-4 text-sm">
            Vas a reservar un turno con el Dr.
            <span class="font-semibold">{slot_value(@selected_slot, :professional_name)}</span>
            el día <span class="font-semibold">{slot_value(@selected_slot, :start_label)}</span>
            hasta <span class="font-semibold">{slot_value(@selected_slot, :end_label)}</span>.
          </div>

          <div class="flex justify-end gap-3">
            <button type="button" class="btn btn-soft btn-secondary" phx-click="close_modal">
              Cancelar
            </button>
            <button type="button" class="btn btn-primary" phx-click="confirm_booking">
              Confirmar Reserva
            </button>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp list_psychologists do
    Accounts.list_users_by_role("psychologist")
    |> Enum.sort_by(&professional_name/1)
  end

  defp load_available_appointments(nil) do
    Scheduling.list_future_available_psychologist_appointments()
  end

  defp load_available_appointments(professional_id) when is_integer(professional_id) do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 120)

    Scheduling.list_available_appointments(professional_id, start_date, end_date)
  end

  defp build_calendar_events(appointments) do
    Enum.map(appointments, fn appointment ->
      %{
        id: appointment.id,
        title: professional_name(appointment),
        start: appointment.start_at |> DateTime.to_naive() |> NaiveDateTime.to_iso8601(),
        end: appointment.end_at |> DateTime.to_naive() |> NaiveDateTime.to_iso8601(),
        classNames: ["fc-event-success"],
        extendedProps: %{
          status: "available",
          professional_name: professional_name(appointment)
        }
      }
    end)
  end

  defp find_appointment(appointments, appointment_id) do
    Enum.find(appointments, &(&1.id == appointment_id))
  end

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil

  defp parse_optional_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> id
      _ -> nil
    end
  end

  defp parse_optional_int(value) when is_integer(value), do: value
  defp parse_optional_int(_), do: nil

  defp parse_appointment_id(value) when is_integer(value), do: {:ok, value}

  defp parse_appointment_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_appointment_id(_), do: {:error, :invalid_id}

  defp format_slot_datetime(value, fallback_datetime) when is_binary(value) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/, value) do
      [_, date, time] -> "#{date} #{time}"
      _ -> Calendar.strftime(fallback_datetime, "%d/%m/%Y %H:%M")
    end
  end

  defp format_slot_datetime(_, fallback_datetime),
    do: Calendar.strftime(fallback_datetime, "%d/%m/%Y %H:%M")

  defp slot_value(nil, _key), do: "-"

  defp slot_value(slot, key) when is_map(slot) do
    Map.get(slot, key) || "-"
  end

  defp professional_name(%{professional: professional}) when is_map(professional),
    do: professional_name(professional)

  defp professional_name(professional) when is_map(professional) do
    cond do
      is_binary(professional.first_name) and is_binary(professional.last_name) ->
        "#{professional.first_name} #{professional.last_name}"

      is_binary(professional.email) ->
        professional.email

      true ->
        "Profesional"
    end
  end

  defp current_student_id(nil), do: fallback_student_id()

  defp current_student_id(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> {:ok, Map.get(user, :id)}
      is_map(user) and is_integer(Map.get(user, "id")) -> {:ok, Map.get(user, "id")}
      true -> fallback_student_id()
    end
  end

  defp fallback_student_id do
    case Accounts.list_users_by_role("student") |> List.first() do
      nil -> {:error, :student_not_found}
      student -> {:ok, student.id}
    end
  end
end
