defmodule CaeWeb.Student.BookAppointmentLive do
  use CaeWeb, :live_view

  alias Cae.Scheduling
  alias Cae.Accounts

  @impl true
  def mount(_params, _session, socket) do
    appointments = Scheduling.list_future_available_psychologist_appointments()

    socket =
      socket
      |> assign(:page_title, "Sacar Turno")
      |> assign(:current_scope, socket.assigns[:current_scope])
      |> assign(:appointments, appointments)
      |> assign(:appointments_grouped, group_by_day(appointments))
      |> assign(:selected_appointment_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_appointment", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {appointment_id, ""} ->
        {:noreply, assign(socket, :selected_appointment_id, appointment_id)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_confirm", _params, socket) do
    {:noreply, assign(socket, :selected_appointment_id, nil)}
  end

  @impl true
  def handle_event("confirm_booking", _params, socket) do
    appointment_id = socket.assigns.selected_appointment_id

    with true <- is_integer(appointment_id),
         {:ok, student_id} <- current_student_id(socket.assigns.current_scope),
         {:ok, _appointment} <-
           Scheduling.book_available_appointment_for_student(appointment_id, student_id) do
      appointments = Scheduling.list_future_available_psychologist_appointments()

      {:noreply,
       socket
       |> assign(:appointments, appointments)
       |> assign(:appointments_grouped, group_by_day(appointments))
       |> assign(:selected_appointment_id, nil)
       |> put_flash(:info, "Turno reservado correctamente")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "Debe seleccionar un turno")}

      {:error, :student_not_found} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar al alumno actual")}

      {:error, :not_available} ->
        appointments = Scheduling.list_future_available_psychologist_appointments()

        {:noreply,
         socket
         |> assign(:appointments, appointments)
         |> assign(:appointments_grouped, group_by_day(appointments))
         |> assign(:selected_appointment_id, nil)
         |> put_flash(:error, "El turno ya no esta disponible")}

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
          <p class="text-sm text-base-content/70">
            Turnos futuros disponibles con profesionales de psicologia.
          </p>
        </div>

        <div
          :if={map_size(@appointments_grouped) == 0}
          class="alert alert-soft alert-info"
          role="alert"
        >
          <span>No hay turnos disponibles por el momento.</span>
        </div>

        <div
          :for={{day, day_appointments} <- @appointments_grouped}
          class="rounded-box border border-base-content/10 bg-base-100 p-4"
        >
          <h3 class="mb-3 text-lg font-semibold">{day}</h3>

          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <article
              :for={appointment <- day_appointments}
              class="rounded-box border border-base-content/10 p-3"
            >
              <p class="text-sm font-semibold">{professional_name(appointment)}</p>
              <p class="text-xs text-base-content/70">
                {time_range(appointment.start_at, appointment.end_at)}
              </p>

              <button
                type="button"
                class="btn btn-primary btn-sm mt-3"
                phx-click="select_appointment"
                phx-value-id={appointment.id}
              >
                Reservar
              </button>
            </article>
          </div>
        </div>
      </section>

      <div
        id="confirm-booking-modal"
        class={[
          "overlay modal overlay-open:opacity-100 overlay-open:duration-300",
          is_nil(@selected_appointment_id) && "hidden"
        ]}
        role="dialog"
        tabindex="-1"
      >
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-header">
              <h3 class="modal-title">Confirmar reserva</h3>
              <button
                type="button"
                class="btn btn-text btn-circle btn-sm absolute end-3 top-3"
                phx-click="close_confirm"
                aria-label="Close"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>

            <div class="modal-body">
              <p>Vas a reservar este turno. Queres continuar?</p>
            </div>

            <div class="modal-footer">
              <button type="button" class="btn btn-soft btn-secondary" phx-click="close_confirm">
                Cancelar
              </button>
              <button type="button" class="btn btn-primary" phx-click="confirm_booking">
                Confirmar
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp group_by_day(appointments) do
    appointments
    |> Enum.group_by(fn appointment ->
      Calendar.strftime(appointment.start_at, "%A %d/%m/%Y")
    end)
    |> Enum.sort_by(fn {day, _} -> day end)
  end

  defp time_range(start_at, end_at) do
    "#{Calendar.strftime(start_at, "%H:%M")} - #{Calendar.strftime(end_at, "%H:%M")}"
  end

  defp professional_name(appointment) do
    professional = appointment.professional

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
