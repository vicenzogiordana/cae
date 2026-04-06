defmodule CaeWeb.Secretary.ScheduleLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @profession_options [
    {"Psicología", "psychology"},
    {"Psicopedagogía", "psychopedagogy"}
  ]

  @profession_role_map %{
    "psychology" => "psychologist",
    "psychopedagogy" => "psychopedagogue"
  }

  @impl true
  def mount(_params, _session, socket) do
    selected_profession = ""
    professionals = list_professionals(selected_profession)
    selected_professional_id = nil
    appointments = load_available_appointments(selected_professional_id)
    events = build_calendar_events(appointments)
    students = list_students()

    {:ok,
     socket
     |> assign(:page_title, "Agenda General")
     |> assign(:current_scope, socket.assigns[:current_scope])
     |> assign(:profession_options, @profession_options)
     |> assign(:selected_profession, selected_profession)
     |> assign(:professionals, professionals)
     |> assign(:selected_professional_id, selected_professional_id)
     |> assign(:appointments, appointments)
     |> assign(:calendar_events, events)
     |> assign(:students, students)
     |> assign(:student_query, "")
     |> assign(:filtered_students, students)
     |> assign(:show_modal, false)
     |> assign(:selected_slot, nil)}
  end

  @impl true
  def handle_event("filters_changed", params, socket) when is_map(params) do
    profession = Map.get(params, "profession", "")
    professional_id = Map.get(params, "professional_id", "")
    professionals = list_professionals(profession)

    selected_professional_id =
      professional_id
      |> normalize_professional_id(professionals)
      |> default_professional_id(professionals)

    appointments = load_available_appointments(selected_professional_id)
    events = build_calendar_events(appointments)

    {:noreply,
     socket
     |> assign(:selected_profession, profession)
     |> assign(:professionals, professionals)
     |> assign(:selected_professional_id, selected_professional_id)
     |> assign(:appointments, appointments)
     |> assign(:calendar_events, events)
     |> push_event("refresh_events", %{events: events})}
  end

  @impl true
  def handle_event("search_students", %{"query" => query}, socket) do
    filtered_students = filter_students(socket.assigns.students, query)

    {:noreply,
     socket
     |> assign(:student_query, query)
     |> assign(:filtered_students, filtered_students)}
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
           Enum.find(appointments, &(&1.id == appointment_id)) do
      slot = %{
        id: appointment.id,
        professional_name: professional_name(appointment),
        start_label: format_slot_datetime(start_at, appointment.start_at),
        end_label: format_slot_datetime(end_at, appointment.end_at)
      }

      {:noreply,
       socket
       |> assign(:selected_slot, slot)
       |> assign(:student_query, "")
       |> assign(:filtered_students, socket.assigns.students)
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
     |> assign(:selected_slot, nil)
     |> assign(:student_query, "")
     |> assign(:filtered_students, socket.assigns.students)}
  end

  @impl true
  def handle_event("confirm_booking", %{"booking" => %{"student_id" => student_id}}, socket) do
    selected_slot = socket.assigns.selected_slot
    appointment_id = selected_slot && selected_slot.id
    selected_professional_id = socket.assigns.selected_professional_id

    with true <- is_integer(appointment_id),
         {:ok, parsed_student_id} <- parse_appointment_id(student_id),
         {:ok, secretary_id} <- current_secretary_id(socket.assigns.current_scope),
         {:ok, _appointment} <-
           Scheduling.book_appointment(appointment_id, parsed_student_id, secretary_id) do
      appointments = load_available_appointments(selected_professional_id)
      events = build_calendar_events(appointments)

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:calendar_events, events)
       |> assign(:show_modal, false)
       |> assign(:selected_slot, nil)
       |> assign(:student_query, "")
       |> assign(:filtered_students, socket.assigns.students)
       |> push_event("refresh_events", %{events: events})
       |> put_flash(:info, "Turno asignado correctamente")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Debe seleccionar un turno")}

      {:error, :invalid_id} ->
        {:noreply, put_flash(socket, :error, "Debe seleccionar un alumno")}

      {:error, :secretary_not_found} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar a la secretaria actual")}

      {:error, "El turno no está disponible"} ->
        appointments = load_available_appointments(selected_professional_id)
        events = build_calendar_events(appointments)

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:calendar_events, events)
         |> assign(:show_modal, false)
         |> assign(:selected_slot, nil)
         |> push_event("refresh_events", %{events: events})
         |> put_flash(:error, "El turno ya no está disponible")}

      {:error, "El alumno ya tiene un turno reservado esta semana"} ->
        {:noreply,
         put_flash(socket, :error, "Ese alumno ya tiene un turno reservado esta semana")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "No se pudo asignar el turno")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div>
          <h2 class="text-2xl font-bold">Agenda General de Secretaria</h2>
          <p class="text-sm text-base-content/70">
            Asigná turnos disponibles por profesional a alumnos.
          </p>
        </div>

        <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
          <form phx-change="filters_changed" class="grid gap-3 md:grid-cols-2">
            <label class="form-control w-full">
              <span class="label-text mb-2">Profesión</span>
              <select name="profession" class="select select-bordered w-full">
                <option value="">Seleccionar profesión</option>
                <option
                  :for={{label, value} <- @profession_options}
                  value={value}
                  selected={@selected_profession == value}
                >
                  {label}
                </option>
              </select>
            </label>

            <label class="form-control w-full">
              <span class="label-text mb-2">Profesional</span>
              <select
                name="professional_id"
                class="select select-bordered w-full"
                disabled={Enum.empty?(@professionals)}
              >
                <option value="">Seleccionar profesional</option>
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
        id="secretary-booking-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">Asignar turno</h3>
              <p class="text-sm text-base-content/70">Seleccioná el alumno para este bloque.</p>
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
            Turno con
            <span class="font-semibold">{slot_value(@selected_slot, :professional_name)}</span>
            el día <span class="font-semibold">{slot_value(@selected_slot, :start_label)}</span>
            hasta <span class="font-semibold">{slot_value(@selected_slot, :end_label)}</span>.
          </div>

          <form phx-change="search_students" class="space-y-2">
            <label class="form-control w-full">
              <span class="label-text">Buscar alumno</span>
              <input
                type="text"
                name="query"
                value={@student_query}
                phx-debounce="250"
                class="input input-bordered w-full"
                placeholder="Nombre o email"
              />
            </label>
          </form>

          <.form for={%{}} as={:booking} id="secretary-booking-form" phx-submit="confirm_booking">
            <div class="space-y-4">
              <label class="form-control w-full">
                <span class="label-text">Alumno</span>
                <select name="booking[student_id]" class="select select-bordered w-full" required>
                  <option value="">Seleccionar alumno</option>
                  <option :for={student <- @filtered_students} value={student.id}>
                    {student_display(student)}
                  </option>
                </select>
              </label>

              <div class="mt-3 flex justify-end gap-3">
                <button type="button" class="btn btn-soft btn-secondary" phx-click="close_modal">
                  Cancelar
                </button>
                <button type="submit" class="btn btn-primary">Confirmar asignación</button>
              </div>
            </div>
          </.form>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp list_professionals(profession_key) do
    case Map.get(@profession_role_map, profession_key) do
      nil -> []
      role -> Accounts.list_users_by_role(role) |> Enum.sort_by(&professional_name/1)
    end
  end

  defp normalize_professional_id(value, professionals) do
    allowed_ids = MapSet.new(Enum.map(professionals, & &1.id))

    case parse_appointment_id(value) do
      {:ok, id} -> if(MapSet.member?(allowed_ids, id), do: id, else: nil)
      _ -> nil
    end
  end

  defp default_professional_id(nil, [first_professional | _]), do: first_professional.id

  defp default_professional_id(selected_professional_id, _professionals),
    do: selected_professional_id

  defp load_available_appointments(nil), do: []

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

  defp list_students do
    Accounts.list_users_by_role("student")
    |> Enum.sort_by(&student_display/1)
  end

  defp filter_students(students, query) when is_binary(query) do
    trimmed = String.trim(query)

    if trimmed == "" do
      students
    else
      needle = String.downcase(trimmed)

      Enum.filter(students, fn student ->
        student
        |> student_display()
        |> String.downcase()
        |> String.contains?(needle)
      end)
    end
  end

  defp student_display(student) when is_map(student) do
    name =
      cond do
        is_binary(student.first_name) and is_binary(student.last_name) ->
          "#{student.first_name} #{student.last_name}"

        is_binary(student.email) ->
          student.email

        true ->
          "Alumno"
      end

    case student.email do
      email when is_binary(email) -> "#{name} (#{email})"
      _ -> name
    end
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

  defp current_secretary_id(nil), do: fallback_secretary_id()

  defp current_secretary_id(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> {:ok, Map.get(user, :id)}
      is_map(user) and is_integer(Map.get(user, "id")) -> {:ok, Map.get(user, "id")}
      true -> fallback_secretary_id()
    end
  end

  defp fallback_secretary_id do
    case Accounts.list_users_by_role("secretary") |> List.first() do
      nil -> {:error, :secretary_not_found}
      secretary -> {:ok, secretary.id}
    end
  end

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
end
