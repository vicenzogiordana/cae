defmodule CaeWeb.Student.AppointmentsLive do
  use CaeWeb, :live_view

  alias Cae.Scheduling
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns[:current_scope]

    {upcoming_appointments, past_appointments} =
      case current_student_id(current_scope) do
        {:ok, student_id} ->
          split_booked_appointments(Scheduling.list_student_appointments(student_id))

        _ ->
          {[], []}
      end

    cancelled_appointments =
      case current_student_id(current_scope) do
        {:ok, student_id} -> Scheduling.list_student_cancellations(student_id)
        _ -> []
      end

    {:ok,
     socket
     |> assign(:page_title, "Mis Turnos")
     |> assign(:current_scope, current_scope)
     |> assign(:upcoming_appointments, upcoming_appointments)
     |> assign(:past_appointments, past_appointments)
     |> assign(:cancelled_appointments, cancelled_appointments)
     |> assign(:show_cancel_modal, false)
     |> assign(:selected_cancel_appointment, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div>
          <h2 class="text-2xl font-bold">Mis Turnos</h2>
          <p class="text-sm text-base-content/70">
            Aca podes ver tus proximos turnos y el historial de atenciones.
          </p>
        </div>

        <section class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Proximos turnos</h3>
            <span class="badge badge-primary badge-soft">{length(@upcoming_appointments)}</span>
          </div>

          <div
            :if={Enum.empty?(@upcoming_appointments)}
            class="alert alert-soft alert-info"
            role="alert"
          >
            <span>No tenes turnos pendientes.</span>
          </div>

          <div
            :if={not Enum.empty?(@upcoming_appointments)}
            class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={appointment <- @upcoming_appointments}
              class="card border border-base-content/10 bg-base-100 shadow-sm"
            >
              <div class="card-body gap-3">
                <div class="flex items-start justify-between gap-3">
                  <h3 class="card-title text-base">{professional_name(appointment)}</h3>
                  <span class={[
                    "badge badge-soft",
                    appointment_status_badge_class(appointment.status)
                  ]}>
                    {appointment_status_label(appointment.status)}
                  </span>
                </div>

                <dl class="space-y-2 text-sm">
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Fecha</dt>
                    <dd class="font-medium">{format_datetime(appointment.start_at, "%d/%m/%Y")}</dd>
                  </div>
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Horario</dt>
                    <dd class="font-medium">
                      {format_datetime(appointment.start_at, "%H:%M")} - {format_datetime(
                        appointment.end_at,
                        "%H:%M"
                      )}
                    </dd>
                  </div>
                </dl>

                <div class="card-actions justify-end pt-2">
                  <button
                    type="button"
                    class="btn btn-soft btn-error btn-sm"
                    phx-click="open_cancel_modal"
                    phx-value-id={appointment.id}
                  >
                    Cancelar turno
                  </button>
                </div>
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
            <span>No hay turnos pasados en tu historial.</span>
          </div>

          <div
            :if={not Enum.empty?(@past_appointments)}
            class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={appointment <- @past_appointments}
              class="card border border-base-content/10 bg-base-100/80 shadow-sm"
            >
              <div class="card-body gap-3">
                <div class="flex items-start justify-between gap-3">
                  <h3 class="card-title text-base">{professional_name(appointment)}</h3>
                  <span class={[
                    "badge badge-soft",
                    appointment_status_badge_class(appointment.status)
                  ]}>
                    {appointment_status_label(appointment.status)}
                  </span>
                </div>

                <dl class="space-y-2 text-sm">
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Fecha</dt>
                    <dd class="font-medium">{format_datetime(appointment.start_at, "%d/%m/%Y")}</dd>
                  </div>
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Horario</dt>
                    <dd class="font-medium">
                      {format_datetime(appointment.start_at, "%H:%M")} - {format_datetime(
                        appointment.end_at,
                        "%H:%M"
                      )}
                    </dd>
                  </div>
                </dl>
              </div>
            </article>
          </div>
        </section>

        <section class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Turnos cancelados</h3>
            <span class="badge badge-error badge-soft">{length(@cancelled_appointments)}</span>
          </div>

          <div :if={Enum.empty?(@cancelled_appointments)} class="alert alert-soft" role="alert">
            <span>No cancelaste turnos todavia.</span>
          </div>

          <div
            :if={not Enum.empty?(@cancelled_appointments)}
            class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3"
          >
            <article
              :for={cancellation <- @cancelled_appointments}
              class="card border border-base-content/10 bg-base-100/80 shadow-sm"
            >
              <div class="card-body gap-3">
                <div class="flex items-start justify-between gap-3">
                  <h3 class="card-title text-base">{professional_name(cancellation)}</h3>
                  <span class={[
                    "badge badge-soft gap-1.5",
                    cancellation_source_badge_class(cancellation.cancelled_by_role)
                  ]}>
                    <.icon
                      name={cancellation_source_icon(cancellation.cancelled_by_role)}
                      class="size-3.5"
                    />
                    {cancellation_source_label(cancellation.cancelled_by_role)}
                  </span>
                </div>

                <dl class="space-y-2 text-sm">
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Fecha original</dt>
                    <dd class="font-medium">{format_datetime(cancellation.start_at, "%d/%m/%Y")}</dd>
                  </div>
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Horario original</dt>
                    <dd class="font-medium">
                      {format_datetime(cancellation.start_at, "%H:%M")} - {format_datetime(
                        cancellation.end_at,
                        "%H:%M"
                      )}
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Cancelado el</dt>
                    <dd class="font-medium">
                      {format_datetime(cancellation.inserted_at, "%d/%m/%Y %H:%M")}
                    </dd>
                  </div>
                  <div class="flex items-center justify-between gap-4">
                    <dt class="text-base-content/60">Cancelado por</dt>
                    <dd class={[
                      "inline-flex items-center gap-1.5 font-medium",
                      cancellation_source_text_class(cancellation.cancelled_by_role)
                    ]}>
                      <.icon
                        name={cancellation_source_icon(cancellation.cancelled_by_role)}
                        class="size-4"
                      />
                      {cancellation_source_description(cancellation.cancelled_by_role)}
                    </dd>
                  </div>
                </dl>
              </div>
            </article>
          </div>
        </section>
      </section>

      <.modal
        :if={@show_cancel_modal}
        id="confirm-cancel-appointment-modal"
        show
        on_cancel={JS.push("close_cancel_modal")}
      >
        <div class="space-y-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="text-xl font-bold">Confirmar cancelación</h3>
              <p class="text-sm text-base-content/70">
                Confirmá si querés cancelar este turno.
              </p>
            </div>

            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="close_cancel_modal"
              aria-label="Cerrar"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <div class="rounded-box border border-base-content/10 bg-base-100 p-4 text-sm">
            Vas a cancelar el turno con
            <span class="font-semibold">
              {slot_value(@selected_cancel_appointment, :professional_name)}
            </span>
            el día
            <span class="font-semibold">
              {slot_value(@selected_cancel_appointment, :start_label)}
            </span>
            hasta <span class="font-semibold">{slot_value(@selected_cancel_appointment, :end_label)}</span>.
          </div>

          <div class="flex justify-end gap-3">
            <button type="button" class="btn btn-soft btn-secondary" phx-click="close_cancel_modal">
              Volver
            </button>
            <button type="button" class="btn btn-error" phx-click="confirm_cancel_appointment">
              Sí, cancelar turno
            </button>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp split_booked_appointments(appointments) when is_list(appointments) do
    now = DateTime.utc_now()

    appointments
    |> Enum.filter(&(&1.status == "booked"))
    |> Enum.split_with(fn appointment ->
      DateTime.compare(appointment.start_at, now) in [:gt, :eq]
    end)
    |> then(fn {upcoming, past} ->
      {
        Enum.sort_by(upcoming, & &1.start_at, DateTime),
        Enum.sort_by(past, & &1.start_at, {:desc, DateTime})
      }
    end)
  end

  @impl true
  def handle_event("open_cancel_modal", %{"id" => id}, socket) do
    with {:ok, appointment_id} <- parse_appointment_id(id),
         appointment when not is_nil(appointment) <-
           find_appointment(socket.assigns.upcoming_appointments, appointment_id) do
      selected_cancel_appointment = %{
        id: appointment.id,
        professional_name: professional_name(appointment),
        start_label: format_datetime(appointment.start_at, "%d/%m/%Y %H:%M"),
        end_label: format_datetime(appointment.end_at, "%d/%m/%Y %H:%M")
      }

      {:noreply,
       socket
       |> assign(:selected_cancel_appointment, selected_cancel_appointment)
       |> assign(:show_cancel_modal, true)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo preparar la cancelación")}
    end
  end

  @impl true
  def handle_event("close_cancel_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_cancel_modal, false)
     |> assign(:selected_cancel_appointment, nil)}
  end

  @impl true
  def handle_event("confirm_cancel_appointment", _params, socket) do
    selected_cancel_appointment = socket.assigns.selected_cancel_appointment
    appointment_id = selected_cancel_appointment && selected_cancel_appointment.id

    with true <- is_integer(appointment_id),
         {:ok, student_id} <- current_student_id(socket.assigns.current_scope),
         {:ok, _appointment} <- Scheduling.cancel_student_appointment(student_id, appointment_id) do
      {upcoming_appointments, past_appointments} =
        split_booked_appointments(Scheduling.list_student_appointments(student_id))

      cancelled_appointments = Scheduling.list_student_cancellations(student_id)

      {:noreply,
       socket
       |> assign(:upcoming_appointments, upcoming_appointments)
       |> assign(:past_appointments, past_appointments)
       |> assign(:cancelled_appointments, cancelled_appointments)
       |> assign(:show_cancel_modal, false)
       |> assign(:selected_cancel_appointment, nil)
       |> put_flash(:info, "Turno cancelado correctamente")}
    else
      false ->
        {:noreply, put_flash(socket, :error, "No se pudo cancelar el turno")}

      {:error, :student_not_found} ->
        {:noreply, put_flash(socket, :error, "No se pudo identificar al alumno actual")}

      {:error, :not_owned} ->
        {:noreply, put_flash(socket, :error, "No podés cancelar un turno que no es tuyo")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "No se encontró el turno")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "No se pudo cancelar el turno")}
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

  defp find_appointment(appointments, appointment_id) do
    Enum.find(appointments, &(&1.id == appointment_id))
  end

  defp slot_value(nil, _key), do: "-"

  defp slot_value(slot, key) when is_map(slot) do
    Map.get(slot, key) || "-"
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
    case Cae.Accounts.list_users_by_role("student") |> List.first() do
      nil -> {:error, :student_not_found}
      student -> {:ok, student.id}
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

  defp appointment_status_label("booked"), do: "Reservado"
  defp appointment_status_label("cancelled"), do: "Cancelado"
  defp appointment_status_label(_), do: "Finalizado"

  defp appointment_status_badge_class("booked"), do: "badge-success"
  defp appointment_status_badge_class("cancelled"), do: "badge-error"
  defp appointment_status_badge_class(_), do: "badge-ghost"

  defp cancellation_source_label("student"), do: "Cancelado por alumno"
  defp cancellation_source_label("professional"), do: "Cancelado por profesional"
  defp cancellation_source_label(_), do: "Cancelado"

  defp cancellation_source_description("student"), do: "Alumno"
  defp cancellation_source_description("professional"), do: "Profesional"
  defp cancellation_source_description(_), do: "Sin registro"

  defp cancellation_source_badge_class("student"), do: "badge-warning"
  defp cancellation_source_badge_class("professional"), do: "badge-error"
  defp cancellation_source_badge_class(_), do: "badge-ghost"

  defp cancellation_source_text_class("student"), do: "text-warning"
  defp cancellation_source_text_class("professional"), do: "text-error"
  defp cancellation_source_text_class(_), do: "text-base-content/70"

  defp cancellation_source_icon("student"), do: "hero-user"
  defp cancellation_source_icon("professional"), do: "hero-user-circle"
  defp cancellation_source_icon(_), do: "hero-question-mark-circle"

  defp format_datetime(%DateTime{} = datetime, format), do: Calendar.strftime(datetime, format)
  defp format_datetime(_, _), do: "-"
end
