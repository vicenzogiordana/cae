defmodule Cae.Scheduling do
  @moduledoc """
  The Scheduling context manages appointments and availability for professionals.

  This context handles:
  - Creating and managing appointment slots (available, booked, cancelled)
  - Bulk generation of availability for professionals
  - Booking appointments by students or secretaries
  - Cancelling appointments
  - Blocking time slots (for maintenance or personal use)
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, warn: false
  alias Cae.Repo
  alias Cae.Scheduling.Appointment
  alias Cae.Scheduling.AppointmentCancellation
  alias Cae.Accounts

  @availability_types %{
    weekday: :string,
    availability_date: :string,
    start_time: :string,
    end_time: :string,
    recurrence: :string
  }

  @availability_required_fields [:weekday, :availability_date, :start_time, :end_time]

  @doc """
  Gets a single appointment by id.

  Raises `Ecto.NoResultsError` if the Appointment does not exist.
  """
  def get_appointment!(id) do
    Appointment
    |> preload([:professional, :student, :booked_by])
    |> Repo.get!(id)
  end

  @doc """
  Gets an appointment by id.

  Returns nil if the Appointment does not exist.
  """
  def get_appointment(id) do
    Appointment
    |> preload([:professional, :student, :booked_by])
    |> Repo.get(id)
  end

  @doc """
  Creates a single appointment slot (available).

  ## Examples

      iex> create_appointment_slot(
      ...>   professional_id,
      ...>   ~U[2026-04-05 10:00:00Z],
      ...>   ~U[2026-04-05 10:30:00Z]
      ... )
      {:ok, %Appointment{}}

  """
  def create_appointment_slot(professional_id, start_at, end_at) do
    %Appointment{}
    |> Appointment.changeset(%{
      professional_id: professional_id,
      start_at: start_at,
      end_at: end_at,
      status: "available"
    })
    |> Repo.insert()
  end

  @doc """
  Bulk creates appointment slots for a professional.

  This is useful for generating availability for a week or month.

  ## Parameters

  - `professional_id`: ID of the professional
  - `start_date`: Date to start generating slots
  - `end_date`: Date to end generating slots
  - `duration_minutes`: Duration of each slot (e.g., 30 minutes)
  - `start_hour`: Hour of day to start (e.g., 9 for 9 AM)
  - `end_hour`: Hour of day to end (e.g., 17 for 5 PM)

  ## Returns

  `{:ok, slots}` or `{:error, reason}`
  """
  def generate_availability(
        professional_id,
        start_date,
        end_date,
        duration_minutes \\ 30,
        start_hour \\ 9,
        end_hour \\ 17
      ) do
    # Verify professional exists
    professional = Accounts.get_user!(professional_id)

    if professional.role not in ["psychologist", "psychiatrist", "psychopedagogue"] do
      {:error, "El usuario no es un profesional"}
    else
      slots =
        generate_slots(
          professional_id,
          start_date,
          end_date,
          duration_minutes,
          start_hour,
          end_hour
        )

      {inserted, _} =
        Enum.map_reduce(slots, [], fn slot, acc ->
          case Repo.insert(slot) do
            {:ok, a} -> {a, [a | acc]}
            {:error, _} -> acc
          end
        end)

      {:ok, inserted}
    end
  end

  defp generate_slots(
         professional_id,
         start_date,
         end_date,
         duration_minutes,
         start_hour,
         end_hour
       ) do
    Date.range(start_date, end_date)
    |> Enum.flat_map(fn date ->
      # Skip weekends (optional - adjust as needed)
      if Date.day_of_week(date) in [6, 7],
        do: [],
        else: generate_day_slots(date, professional_id, duration_minutes, start_hour, end_hour)
    end)
  end

  defp generate_day_slots(date, professional_id, duration_minutes, start_hour, end_hour) do
    start_time = DateTime.new!(date, Time.new!(start_hour, 0, 0), "Etc/UTC")

    Stream.unfold(start_time, fn current_time ->
      end_time = DateTime.add(current_time, duration_minutes * 60)
      current_hour = current_time.hour

      if current_hour >= end_hour do
        nil
      else
        slot = %Appointment{
          professional_id: professional_id,
          start_at: current_time,
          end_at: end_time,
          status: "available"
        }

        {slot, end_time}
      end
    end)
    |> Enum.to_list()
  end

  @doc """
  Lists available appointments for a professional.

  Optionally filters by date range.
  """
  def list_available_appointments(professional_id, start_date \\ nil, end_date \\ nil) do
    query =
      from(a in Appointment,
        where: [professional_id: ^professional_id, status: "available"],
        preload: [:professional, :student, :booked_by],
        order_by: a.start_at
      )

    query =
      if start_date && end_date do
        from(a in query,
          where:
            fragment("?::date >= ?", a.start_at, ^start_date) and
              fragment("?::date <= ?", a.start_at, ^end_date)
        )
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists appointments for a student (student view - only their bookings).
  """
  def list_student_appointments(student_id) do
    Appointment
    |> where([a], a.student_id == ^student_id)
    |> preload([:professional, :student, :booked_by])
    |> order_by(desc: :start_at)
    |> Repo.all()
  end

  @doc """
  Returns the nearest booked appointment for a student within the next 7 days.

  Returns nil when no upcoming appointment is found in that window.
  """
  def get_upcoming_reminder(student_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    seven_days_from_now = DateTime.add(now, 7 * 24 * 60 * 60, :second)

    from(a in Appointment,
      where:
        a.student_id == ^student_id and
          a.status == "booked" and
          a.start_at >= ^now and
          a.start_at <= ^seven_days_from_now,
      preload: [:professional],
      order_by: [asc: a.start_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Lists appointments for a professional (their schedule).
  """
  def list_professional_appointments(professional_id, start_date \\ nil, end_date \\ nil) do
    query =
      from(a in Appointment,
        where: a.professional_id == ^professional_id,
        preload: [:professional, :student, :booked_by],
        order_by: a.start_at
      )

    query =
      if start_date && end_date do
        from(a in query,
          where:
            fragment("?::date >= ?", a.start_at, ^start_date) and
              fragment("?::date <= ?", a.start_at, ^end_date)
        )
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Books an available appointment (student or secretary action).

  ## Parameters

  - `appointment_id`: ID of the available slot
  - `student_id`: ID of the student booking
  - `booked_by_id`: ID of the person making the booking (student or secretary)

  ## Returns

  {:ok, appointment} or {:error, changeset}
  """
  def book_appointment(appointment_id, student_id, booked_by_id) do
    case mark_appointment_as_booked(appointment_id, student_id, booked_by_id) do
      {:ok, appointment} ->
        {:ok, appointment}

      {:error, :not_available} ->
        {:error, "El turno no está disponible"}

      {:error, :weekly_limit_reached} ->
        {:error, "El alumno ya tiene un turno reservado esta semana"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Cancels an appointment.

  Returns {:ok, appointment} or {:error, changeset}
  """
  def cancel_appointment(appointment_id) do
    appointment = get_appointment!(appointment_id)

    appointment
    |> Appointment.cancel_changeset()
    |> Repo.update()
  end

  @doc """
  Cancels a booked appointment only when it belongs to the given student.
  """
  def cancel_student_appointment(student_id, appointment_id) do
    Repo.transaction(fn ->
      case get_appointment(appointment_id) do
        %Appointment{student_id: ^student_id, status: "booked"} = appointment ->
          cancellation_attrs = %{
            appointment_id: appointment.id,
            student_id: student_id,
            professional_id: appointment.professional_id,
            cancelled_by_role: "student",
            start_at: appointment.start_at,
            end_at: appointment.end_at
          }

          case %AppointmentCancellation{}
               |> AppointmentCancellation.changeset(cancellation_attrs)
               |> Repo.insert() do
            {:ok, _cancellation} ->
              case appointment
                   |> Appointment.changeset(%{
                     status: "available",
                     student_id: nil,
                     booked_by_id: nil
                   })
                   |> Repo.update() do
                {:ok, appointment} -> appointment
                {:error, changeset} -> Repo.rollback(changeset)
              end

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        %Appointment{} ->
          Repo.rollback(:not_owned)

        nil ->
          Repo.rollback(:not_found)
      end
    end)
  end

  @doc """
  Cancels a booked appointment from the professional side and records cancellation source.
  """
  def cancel_professional_appointment(professional_id, appointment_id) do
    Repo.transaction(fn ->
      case get_appointment(appointment_id) do
        %Appointment{professional_id: ^professional_id, status: "booked"} = appointment ->
          cancellation_attrs = %{
            appointment_id: appointment.id,
            student_id: appointment.student_id,
            professional_id: professional_id,
            cancelled_by_role: "professional",
            start_at: appointment.start_at,
            end_at: appointment.end_at
          }

          case %AppointmentCancellation{}
               |> AppointmentCancellation.changeset(cancellation_attrs)
               |> Repo.insert() do
            {:ok, _cancellation} ->
              case appointment
                   |> Appointment.cancel_changeset()
                   |> Repo.update() do
                {:ok, appointment} -> appointment
                {:error, changeset} -> Repo.rollback(changeset)
              end

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        %Appointment{} ->
          Repo.rollback(:not_owned)

        nil ->
          Repo.rollback(:not_found)
      end
    end)
  end

  @doc """
  Lists cancellation history for a student.
  """
  def list_student_cancellations(student_id) do
    from(c in AppointmentCancellation,
      where: c.student_id == ^student_id,
      preload: [:professional, :student],
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Lists appointment IDs that were recently released by cancellation for a professional.
  """
  def list_recently_released_appointment_ids(professional_id, hours \\ 24)
      when is_integer(hours) and hours > 0 do
    cutoff = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    from(c in AppointmentCancellation,
      where: c.professional_id == ^professional_id and c.inserted_at >= ^cutoff,
      select: c.appointment_id,
      distinct: true
    )
    |> Repo.all()
  end

  @doc """
  Checks if a professional has availability in a given time range.
  """
  def has_availability?(professional_id, start_at, end_at) do
    count =
      from(a in Appointment,
        where:
          a.professional_id == ^professional_id and
            a.status == "available" and
            a.start_at >= ^start_at and
            a.end_at <= ^end_at
      )
      |> Repo.aggregate(:count)

    count > 0
  end

  @doc """
  Counts available slots for a professional.
  """
  def count_available_slots(professional_id, start_date \\ nil, end_date \\ nil) do
    query =
      from(a in Appointment,
        where: a.professional_id == ^professional_id and a.status == "available"
      )

    query =
      if start_date && end_date do
        from(a in query,
          where:
            fragment("?::date >= ?", a.start_at, ^start_date) and
              fragment("?::date <= ?", a.start_at, ^end_date)
        )
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc """
  Deletes an appointment.
  """
  def delete_appointment(%Appointment{} = appointment) do
    Repo.delete(appointment)
  end

  @doc """
  Creates recurring availability in bulk using a single `insert_all` inside a transaction.

  Parameters are expected as strings from LiveView forms:
  - weekday: "1".."7" (1 Monday, 7 Sunday)
  - start_time: "HH:MM"
  - end_time: "HH:MM"
  - duration_minutes: "20", "30", etc.
  - repeat_weeks: "1", "4", "8", "16"
  """
  def create_recurring_availability(
        professional_id,
        weekday,
        availability_date,
        start_time,
        end_time,
        duration_minutes,
        gap_minutes,
        recurrence
      ) do
    with {:ok, professional} <- fetch_professional(professional_id),
         {:ok, weekday_int} <- parse_weekday(weekday),
         {:ok, anchor_date} <- parse_date(availability_date),
         {:ok, duration_int} <- parse_positive_int(duration_minutes),
         {:ok, gap_int} <- parse_non_negative_int(gap_minutes),
         {:ok, recurrence_dates} <- recurrence_dates_for(anchor_date, weekday_int, recurrence),
         {:ok, start_time_struct} <- parse_time(start_time),
         {:ok, end_time_struct} <- parse_time(end_time),
         :ok <- validate_time_range(start_time_struct, end_time_struct) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        build_entries_for_dates(
          professional.id,
          recurrence_dates,
          start_time_struct,
          end_time_struct,
          duration_int,
          gap_int,
          now
        )

      Repo.transaction(fn ->
        {inserted_count, _} = Repo.insert_all(Appointment, entries)
        inserted_count
      end)
    end
  end

  def create_recurring_availability(
        professional_id,
        weekday,
        start_time,
        end_time,
        duration_minutes,
        gap_minutes,
        recurrence
      ) do
    create_recurring_availability(
      professional_id,
      weekday,
      Date.to_iso8601(Date.utc_today()),
      start_time,
      end_time,
      duration_minutes,
      gap_minutes,
      recurrence
    )
  end

  @doc """
  Creates availability from LiveView form params using default slot duration and gap.

  Returns:
  - `{:ok, inserted_count}` when slots are created
  - `{:error, changeset}` for validation errors suitable for `to_form/2`
  """
  def create_availability(professional_id, params) when is_map(params) do
    params = stringify_keys(params)

    recurrence =
      Map.get(params, "recurrence", "none")
      |> to_string()

    weekday =
      weekday_from_date(Map.get(params, "availability_date")) || Map.get(params, "weekday")

    with {:ok, duration_minutes} <- duration_minutes_from_range(params) do
      case create_recurring_availability(
             professional_id,
             weekday,
             Map.get(params, "availability_date"),
             Map.get(params, "start_time"),
             Map.get(params, "end_time"),
             duration_minutes,
             0,
             recurrence
           ) do
        {:ok, 0} ->
          {:error,
           availability_changeset(
             params,
             :no_slots_generated
           )}

        {:ok, inserted_count} ->
          {:ok, inserted_count}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, changeset}

        {:error, reason} ->
          {:error, availability_changeset(params, reason)}
      end
    else
      {:error, reason} -> {:error, availability_changeset(params, reason)}
    end
  end

  def create_recurring_availability(
        professional_id,
        weekday,
        start_time,
        end_time,
        duration_minutes,
        repeat_weeks
      ) do
    create_recurring_availability(
      professional_id,
      weekday,
      start_time,
      end_time,
      duration_minutes,
      0,
      repeat_weeks
    )
  end

  @doc """
  Returns future available appointments for professionals with psychologist role.
  """
  def list_future_available_psychologist_appointments do
    now = DateTime.utc_now()

    from(a in Appointment,
      join: p in assoc(a, :professional),
      where: a.status == "available",
      where: a.start_at > ^now,
      where: p.role == "psychologist",
      preload: [professional: p],
      order_by: [asc: a.start_at]
    )
    |> Repo.all()
  end

  @doc """
  Atomically books an appointment only if it is currently available.
  """
  def book_available_appointment_for_student(appointment_id, student_id) do
    mark_appointment_as_booked(appointment_id, student_id, student_id)
  end

  defp mark_appointment_as_booked(appointment_id, student_id, booked_by_id) do
    Repo.transaction(fn ->
      case get_appointment(appointment_id) do
        %Appointment{status: "available", start_at: start_at} ->
          if student_has_booking_in_week?(student_id, start_at) do
            Repo.rollback(:weekly_limit_reached)
          else
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            query =
              from(a in Appointment,
                where: a.id == ^appointment_id and a.status == "available"
              )

            case Repo.update_all(query,
                   set: [
                     status: "booked",
                     student_id: student_id,
                     booked_by_id: booked_by_id,
                     updated_at: now
                   ]
                 ) do
              {1, _} -> get_appointment!(appointment_id)
              _ -> Repo.rollback(:not_available)
            end
          end

        %Appointment{} ->
          Repo.rollback(:not_available)

        nil ->
          Repo.rollback(:not_available)
      end
    end)
  end

  defp student_has_booking_in_week?(student_id, start_at) do
    target_date = DateTime.to_date(start_at)
    week_start = Date.beginning_of_week(target_date)
    week_end = Date.end_of_week(target_date)

    query =
      from(a in Appointment,
        where:
          a.student_id == ^student_id and
            a.status == "booked" and
            fragment("?::date", a.start_at) >= ^week_start and
            fragment("?::date", a.start_at) <= ^week_end
      )

    Repo.aggregate(query, :count) > 0
  end

  defp fetch_professional(professional_id) do
    professional = Repo.get(Cae.Accounts.User, professional_id)

    cond do
      is_nil(professional) ->
        {:error, :professional_not_found}

      professional.role in ["psychologist", "psychiatrist", "psychopedagogue"] ->
        {:ok, professional}

      true ->
        {:error, :not_professional}
    end
  end

  defp parse_weekday(value) do
    with {:ok, integer} <- parse_positive_int(value),
         true <- integer >= 1 and integer <= 7 do
      {:ok, integer}
    else
      _ -> {:error, :invalid_weekday}
    end
  end

  defp parse_positive_int(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_duration}
    end
  end

  defp parse_positive_int(_), do: {:error, :invalid_duration}

  defp parse_non_negative_int(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_non_negative_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> {:ok, integer}
      _ -> {:error, :invalid_gap}
    end
  end

  defp parse_non_negative_int(_), do: {:error, :invalid_gap}

  defp recurrence_dates_for(anchor_date, weekday, recurrence) when is_binary(recurrence) do
    first_date = next_weekday_on_or_after(anchor_date, weekday)

    case recurrence do
      "none" -> {:ok, [first_date]}
      "never" -> {:ok, [first_date]}
      "weekly" -> {:ok, weekly_dates(first_date, 3)}
      "monthly" -> {:ok, weekly_dates_until(first_date, end_of_month(anchor_date))}
      "semester" -> {:ok, weekly_dates_until(first_date, end_of_semester(anchor_date))}
      _ -> {:error, :invalid_repeat_weeks}
    end
  end

  defp recurrence_dates_for(anchor_date, weekday, value) do
    first_date = next_weekday_on_or_after(anchor_date, weekday)

    with {:ok, repeat_weeks} <- parse_positive_int(value) do
      {:ok, weekly_dates(first_date, repeat_weeks)}
    end
  end

  defp parse_time(value) when is_binary(value) do
    normalized = if String.length(value) == 5, do: value <> ":00", else: value

    case Time.from_iso8601(normalized) do
      {:ok, time} -> {:ok, time}
      _ -> {:error, :invalid_time}
    end
  end

  defp parse_time(_), do: {:error, :invalid_time}

  defp stringify_keys(params) do
    Map.new(params, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp availability_changeset(params, reason) do
    {%{}, @availability_types}
    |> cast(params, [:weekday, :availability_date, :start_time, :end_time, :recurrence])
    |> validate_required(@availability_required_fields)
    |> validate_inclusion(:recurrence, ["none", "never", "weekly", "monthly", "semester"])
    |> map_availability_error(reason)
    |> Map.put(:action, :insert)
  end

  defp map_availability_error(changeset, :invalid_weekday),
    do: add_error(changeset, :weekday, "Dia de semana invalido")

  defp map_availability_error(changeset, :invalid_time),
    do: add_error(changeset, :start_time, "Formato de hora invalido")

  defp map_availability_error(changeset, :invalid_time_range),
    do: add_error(changeset, :end_time, "La hora de fin debe ser posterior a la hora de inicio")

  defp map_availability_error(changeset, :no_slots_generated),
    do: add_error(changeset, :end_time, "No se pudo crear disponibilidad para ese rango horario")

  defp map_availability_error(changeset, :invalid_repeat_weeks),
    do: add_error(changeset, :recurrence, "Recurrencia invalida")

  defp map_availability_error(changeset, :professional_not_found),
    do: add_error(changeset, :weekday, "Profesional no encontrado")

  defp map_availability_error(changeset, :not_professional),
    do: add_error(changeset, :weekday, "El usuario no es un profesional valido")

  defp map_availability_error(changeset, :invalid_duration),
    do: add_error(changeset, :start_time, "No se pudo interpretar la duracion de los bloques")

  defp map_availability_error(changeset, :invalid_gap),
    do: add_error(changeset, :start_time, "No se pudo interpretar la pausa entre bloques")

  defp map_availability_error(changeset, _reason),
    do: add_error(changeset, :start_time, "No se pudo guardar la disponibilidad")

  defp duration_minutes_from_range(params) do
    with {:ok, start_time} <- parse_time(Map.get(params, "start_time")),
         {:ok, end_time} <- parse_time(Map.get(params, "end_time")),
         :ok <- validate_time_range(start_time, end_time) do
      minutes = div(Time.diff(end_time, start_time, :second), 60)

      if minutes > 0 do
        {:ok, minutes}
      else
        {:error, :invalid_time_range}
      end
    end
  end

  defp weekday_from_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Integer.to_string(Date.day_of_week(date))
      _ -> nil
    end
  end

  defp weekday_from_date(_), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_date(_), do: {:error, :invalid_date}

  defp validate_time_range(start_time, end_time) do
    if Time.compare(start_time, end_time) == :lt do
      :ok
    else
      {:error, :invalid_time_range}
    end
  end

  defp build_entries_for_dates(
         professional_id,
         recurrence_dates,
         start_time,
         end_time,
         duration_minutes,
         gap_minutes,
         now
       ) do
    recurrence_dates
    |> Enum.flat_map(fn date ->
      build_day_entries(
        date,
        professional_id,
        start_time,
        end_time,
        duration_minutes,
        gap_minutes,
        now
      )
    end)
  end

  defp weekly_dates(first_date, repeat_weeks) do
    0..(repeat_weeks - 1)
    |> Enum.map(fn week_offset -> Date.add(first_date, week_offset * 7) end)
  end

  defp weekly_dates_until(first_date, end_date) do
    Stream.iterate(first_date, &Date.add(&1, 7))
    |> Enum.take_while(&(Date.compare(&1, end_date) != :gt))
  end

  defp end_of_month(%Date{} = date) do
    %Date{date | day: Date.days_in_month(date)}
  end

  defp end_of_semester(anchor_date) do
    anchor_date
    |> add_months(3)
    |> end_of_month()
  end

  defp add_months(%Date{year: year, month: month} = date, months_to_add) do
    total_months = year * 12 + month - 1 + months_to_add
    new_year = div(total_months, 12)
    new_month = rem(total_months, 12) + 1
    day = min(date.day, Date.days_in_month(Date.new!(new_year, new_month, 1)))

    Date.new!(new_year, new_month, day)
  end

  defp build_day_entries(
         date,
         professional_id,
         start_time,
         end_time,
         duration_minutes,
         gap_minutes,
         now
       ) do
    day_start = NaiveDateTime.new!(date, start_time)
    day_end = NaiveDateTime.new!(date, end_time)
    step_seconds = (duration_minutes + gap_minutes) * 60

    Stream.iterate(day_start, &NaiveDateTime.add(&1, step_seconds, :second))
    |> Enum.take_while(fn slot_start ->
      slot_end = NaiveDateTime.add(slot_start, duration_minutes * 60, :second)
      NaiveDateTime.compare(slot_end, day_end) != :gt
    end)
    |> Enum.map(fn slot_start ->
      slot_end = NaiveDateTime.add(slot_start, duration_minutes * 60, :second)
      start_at = DateTime.from_naive!(slot_start, "Etc/UTC")
      end_at = DateTime.from_naive!(slot_end, "Etc/UTC")

      %{
        professional_id: professional_id,
        student_id: nil,
        booked_by_id: nil,
        start_at: start_at,
        end_at: end_at,
        status: "available",
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp next_weekday_on_or_after(date, weekday) do
    current = Date.day_of_week(date)
    days_until = rem(weekday - current + 7, 7)
    Date.add(date, days_until)
  end
end
