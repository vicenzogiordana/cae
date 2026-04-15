defmodule CaeWeb.Clinic.PatientConsultationBookingLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @allowed_roles ["psychologist", "psychiatrist", "psychopedagogue"]

  @impl true
  def mount(%{"student_id" => student_id}, _session, socket) do
    current_scope = socket.assigns[:current_scope]
    current_user = current_scope_user(current_scope)

    with {:ok, current_role} <- role_from_user(current_user),
         true <- current_role in @allowed_roles,
         {:ok, parsed_student_id} <- parse_id(student_id),
         %Accounts.User{} = student <- Accounts.get_user_by(id: parsed_student_id),
         true <- student.role == "student" do
      psychiatrists = list_psychiatrists()
      selected_psychiatrist_id = psychiatrists |> List.first() |> maybe_professional_id()
      appointments = load_available_appointments(selected_psychiatrist_id)
      events = build_calendar_events(appointments)
      can_book_psychiatry = current_role == "psychologist"

      {:ok,
       socket
       |> assign(:page_title, "Reservar interconsulta")
       |> assign(:current_scope, current_scope)
       |> assign(:current_role, current_role)
       |> assign(:can_book_psychiatry, can_book_psychiatry)
       |> assign(:student, student)
       |> assign(:psychiatrists, psychiatrists)
       |> assign(:selected_psychiatrist_id, selected_psychiatrist_id)
       |> assign(:appointments, appointments)
       |> assign(:calendar_events, events)
       |> assign(:show_modal, false)
       |> assign(:selected_slot, nil)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "No tenés permisos para acceder a esta sección")
         |> push_navigate(to: ~p"/live/clinic/schedule")}
    end
  end

  @impl true
  def handle_event("filter_psychiatrist", %{"professional_id" => professional_id}, socket) do
    selected_psychiatrist_id = parse_optional_int(professional_id)
    appointments = load_available_appointments(selected_psychiatrist_id)
    events = build_calendar_events(appointments)

    {:noreply,
     socket
     |> assign(:selected_psychiatrist_id, selected_psychiatrist_id)
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

    with true <- socket.assigns.can_book_psychiatry,
         {:ok, appointment_id} <- parse_id(id),
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
      false ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Solo psicología puede derivar y reservar turnos con psiquiatría"
         )}

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
    selected_psychiatrist_id = socket.assigns.selected_psychiatrist_id

    with true <- socket.assigns.can_book_psychiatry,
         true <- is_integer(appointment_id),
         {:ok, booked_by_id} <- current_user_id(socket.assigns.current_scope),
         {:ok, _appointment} <-
           Scheduling.book_appointment(appointment_id, socket.assigns.student.id, booked_by_id) do
      appointments = load_available_appointments(selected_psychiatrist_id)
      events = build_calendar_events(appointments)

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:calendar_events, events)
       |> assign(:show_modal, false)
       |> assign(:selected_slot, nil)
       |> push_event("refresh_events", %{events: events})
       |> put_flash(:info, "Interconsulta reservada correctamente")}
    else
      false ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Solo psicología puede derivar y reservar turnos con psiquiatría"
         )}

      {:error, :user_not_found} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar al profesional actual")}

      {:error, "El turno no está disponible"} ->
        appointments = load_available_appointments(selected_psychiatrist_id)
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
        {:noreply, put_flash(socket, :error, "El alumno ya tiene un turno reservado esta semana")}

      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo reservar la interconsulta")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h2 class="text-2xl font-bold">Reserva de Interconsulta Psiquiátrica</h2>
            <p class="text-sm text-base-content/70">
              Alumno: <span class="font-semibold">{student_name(@student)}</span>
            </p>
          </div>

          <.link
            navigate={~p"/live/clinic/patients/#{@student.id}"}
            class="btn btn-soft btn-secondary btn-sm"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Volver a ficha clínica
          </.link>
        </div>

        <div :if={!@can_book_psychiatry} class="alert alert-soft alert-warning" role="alert">
          <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
          <span>
            Solo psicología puede derivar y reservar turnos con psiquiatría. Esta vista queda en
            modo consulta para tu rol actual.
          </span>
        </div>

        <div class="rounded-box border border-base-content/10 bg-base-100 p-4">
          <form phx-change="filter_psychiatrist" class="flex flex-col gap-3 sm:flex-row sm:items-end">
            <label class="form-control w-full sm:max-w-sm">
              <span class="label-text mb-2">Psiquiatra</span>
              <select name="professional_id" class="select select-bordered w-full">
                <option value="">Todos los psiquiatras</option>
                <option
                  :for={professional <- @psychiatrists}
                  value={professional.id}
                  selected={to_string(@selected_psychiatrist_id || "") == to_string(professional.id)}
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
          <span>No hay turnos de psiquiatría disponibles para el filtro seleccionado.</span>
        </div>
      </section>

      <.modal
        :if={@show_modal}
        id="clinic-referral-booking-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">Confirmar interconsulta</h3>
              <p class="text-sm text-base-content/70">Se reservará el turno para el alumno actual.</p>
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
            Alumno: <span class="font-semibold">{student_name(@student)}</span>
            <br /> Psiquiatra:
            <span class="font-semibold">{slot_value(@selected_slot, :professional_name)}</span>
            <br /> Día: <span class="font-semibold">{slot_value(@selected_slot, :start_label)}</span>
            hasta <span class="font-semibold">{slot_value(@selected_slot, :end_label)}</span>.
          </div>

          <div class="flex justify-end gap-3">
            <button type="button" class="btn btn-soft btn-secondary" phx-click="close_modal">
              Cancelar
            </button>
            <button type="button" class="btn btn-primary" phx-click="confirm_booking">
              Confirmar reserva
            </button>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp list_psychiatrists do
    Accounts.list_users_by_role("psychiatrist")
    |> Enum.sort_by(&professional_name/1)
  end

  defp maybe_professional_id(nil), do: nil
  defp maybe_professional_id(professional), do: professional.id

  defp load_available_appointments(nil) do
    psychiatrists = list_psychiatrists()
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 120)

    psychiatrists
    |> Enum.flat_map(fn psychiatrist ->
      Scheduling.list_available_appointments(psychiatrist.id, start_date, end_date)
    end)
    |> Enum.sort_by(& &1.start_at, DateTime)
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

  defp parse_id(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_), do: {:error, :invalid_id}

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

  defp student_name(student) when is_map(student) do
    cond do
      is_binary(student.first_name) and is_binary(student.last_name) ->
        "#{student.first_name} #{student.last_name}"

      is_binary(student.email) ->
        student.email

      true ->
        "Alumno"
    end
  end

  defp student_name(_), do: "Alumno"

  defp professional_name(%{professional: professional}) when is_map(professional),
    do: professional_name(professional)

  defp professional_name(professional) when is_map(professional) do
    cond do
      is_binary(professional.first_name) and is_binary(professional.last_name) ->
        "#{professional.first_name} #{professional.last_name}"

      is_binary(professional.email) ->
        professional.email

      true ->
        "Psiquiatra"
    end
  end

  defp current_scope_user(current_scope) when is_map(current_scope) do
    Map.get(current_scope, :user) ||
      Map.get(current_scope, "user") ||
      Map.get(current_scope, :current_user) ||
      Map.get(current_scope, "current_user")
  end

  defp current_scope_user(_), do: nil

  defp current_user_id(current_scope) do
    case current_scope_user(current_scope) do
      user when is_map(user) ->
        cond do
          is_integer(Map.get(user, :id)) -> {:ok, Map.get(user, :id)}
          is_integer(Map.get(user, "id")) -> {:ok, Map.get(user, "id")}
          true -> {:error, :user_not_found}
        end

      _ ->
        {:error, :user_not_found}
    end
  end

  defp role_from_user(user) when is_map(user) do
    role = Map.get(user, :role) || Map.get(user, "role")
    if is_binary(role), do: {:ok, role}, else: {:error, :role_not_found}
  end

  defp role_from_user(_), do: {:error, :role_not_found}
end
