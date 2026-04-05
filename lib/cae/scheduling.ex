defmodule Cae.Scheduling do
  @moduledoc """
  The Scheduling context manages appointments and availability for professionals.

  This context handles:
  - Creating and managing appointment slots (available, booked, blocked, cancelled)
  - Bulk generation of availability for professionals
  - Booking appointments by students or secretaries
  - Cancelling appointments
  - Blocking time slots (for maintenance or personal use)
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, warn: false
  alias Cae.Repo
  alias Cae.Scheduling.Appointment
  alias Cae.Accounts

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
        where: a.professional_id == ^professional_id and a.status == "available",
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
    appointment = get_appointment!(appointment_id)

    if appointment.status != "available" do
      {:error, "El turno no está disponible"}
    else
      appointment
      |> Appointment.book_changeset(%{
        student_id: student_id,
        booked_by_id: booked_by_id,
        status: "booked"
      })
      |> Repo.update()
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
  Blocks a time slot (professional or admin only).

  Used to mark time as unavailable for personal reasons.
  """
  def block_appointment(appointment_id) do
    appointment = get_appointment!(appointment_id)

    appointment
    |> Appointment.block_changeset(%{status: "blocked"})
    |> Repo.update()
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
  Deletes an appointment (useful for removing blocked or cancelled slots).
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
        start_time,
        end_time,
        duration_minutes,
        repeat_weeks
      ) do
    with {:ok, professional} <- fetch_professional(professional_id),
         {:ok, weekday_int} <- parse_weekday(weekday),
         {:ok, duration_int} <- parse_positive_int(duration_minutes),
         {:ok, repeat_weeks_int} <- parse_positive_int(repeat_weeks),
         {:ok, start_time_struct} <- parse_time(start_time),
         {:ok, end_time_struct} <- parse_time(end_time),
         :ok <- validate_time_range(start_time_struct, end_time_struct) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        build_recurring_entries(
          professional.id,
          Date.utc_today(),
          weekday_int,
          start_time_struct,
          end_time_struct,
          duration_int,
          repeat_weeks_int,
          now
        )

      Repo.transaction(fn ->
        {inserted_count, _} = Repo.insert_all(Appointment, entries)
        inserted_count
      end)
    end
  end

  @doc """
  Returns future available appointments for professionals with psychologist role.
  """
  def list_future_available_psychologist_appointments do
    now = DateTime.utc_now()

    from(a in Appointment,
      join: p in assoc(a, :professional),
      where: a.status == "available" and a.start_at > ^now and p.role == "psychologist",
      preload: [professional: p],
      order_by: [asc: a.start_at]
    )
    |> Repo.all()
  end

  @doc """
  Atomically books an appointment only if it is currently available.
  """
  def book_available_appointment_for_student(appointment_id, student_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      query =
        from(a in Appointment,
          where: a.id == ^appointment_id and a.status == "available"
        )

      case Repo.update_all(query,
             set: [
               status: "booked",
               student_id: student_id,
               booked_by_id: student_id,
               updated_at: now
             ],
             returning: true
           ) do
        {1, [appointment]} -> Repo.preload(appointment, [:professional, :student, :booked_by])
        _ -> Repo.rollback(:not_available)
      end
    end)
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

  defp parse_time(value) when is_binary(value) do
    normalized = if String.length(value) == 5, do: value <> ":00", else: value

    case Time.from_iso8601(normalized) do
      {:ok, time} -> {:ok, time}
      _ -> {:error, :invalid_time}
    end
  end

  defp parse_time(_), do: {:error, :invalid_time}

  defp validate_time_range(start_time, end_time) do
    if Time.compare(start_time, end_time) == :lt do
      :ok
    else
      {:error, :invalid_time_range}
    end
  end

  defp build_recurring_entries(
         professional_id,
         from_date,
         weekday,
         start_time,
         end_time,
         duration_minutes,
         repeat_weeks,
         now
       ) do
    first_date = next_weekday_on_or_after(from_date, weekday)

    0..(repeat_weeks - 1)
    |> Enum.flat_map(fn week_offset ->
      date = Date.add(first_date, week_offset * 7)
      build_day_entries(date, professional_id, start_time, end_time, duration_minutes, now)
    end)
  end

  defp build_day_entries(date, professional_id, start_time, end_time, duration_minutes, now) do
    day_start = NaiveDateTime.new!(date, start_time)
    day_end = NaiveDateTime.new!(date, end_time)

    Stream.iterate(day_start, &NaiveDateTime.add(&1, duration_minutes * 60, :second))
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
