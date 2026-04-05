defmodule CaeNew.Scheduling do
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
  alias CaeNew.Repo
  alias CaeNew.Scheduling.Appointment
  alias CaeNew.Accounts

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
end
