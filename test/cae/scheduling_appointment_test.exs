defmodule Cae.SchedulingAppointmentTest do
  use Cae.DataCase

  alias Cae.Scheduling
  alias Cae.Accounts

  setup do
    {:ok, prof} =
      Accounts.create_professional(%{
        "university_id" => "PROF-TST-#{System.unique_integer()}",
        "email" => "prof-tst-#{System.unique_integer()}@uni.edu",
        "first_name" => "Dr.",
        "last_name" => "Specialist",
        "role" => "psychologist"
      })

    {:ok, result} =
      Accounts.register_student(%{
        "university_id" => "STU-TST-#{System.unique_integer()}",
        "email" => "student-tst-#{System.unique_integer()}@uni.edu",
        "first_name" => "Juan",
        "last_name" => "Pérez"
      })

    {:ok, prof: prof, student: result.user}
  end

  test "create_appointment_slot/3 creates an available slot", %{prof: prof} do
    start_at = ~U[2026-04-10 10:00:00Z]
    end_at = ~U[2026-04-10 10:30:00Z]

    {:ok, appointment} = Scheduling.create_appointment_slot(prof.id, start_at, end_at)

    assert appointment.professional_id == prof.id
    assert appointment.status == "available"
    assert appointment.start_at == start_at
    assert appointment.end_at == end_at
  end

  test "book_appointment/3 books an available slot", %{prof: prof, student: student} do
    {:ok, slot} =
      Scheduling.create_appointment_slot(
        prof.id,
        ~U[2026-04-10 11:00:00Z],
        ~U[2026-04-10 11:30:00Z]
      )

    {:ok, booked} = Scheduling.book_appointment(slot.id, student.id, student.id)

    assert booked.status == "booked"
    assert booked.student_id == student.id
  end

  test "cancel_appointment/1 cancels a booking", %{prof: prof, student: student} do
    {:ok, slot} =
      Scheduling.create_appointment_slot(
        prof.id,
        ~U[2026-04-10 12:00:00Z],
        ~U[2026-04-10 12:30:00Z]
      )

    {:ok, booked} = Scheduling.book_appointment(slot.id, student.id, student.id)
    {:ok, cancelled} = Scheduling.cancel_appointment(booked.id)

    assert cancelled.status == "cancelled"
  end

  test "list_student_appointments/1 lists student bookings", %{prof: prof, student: student} do
    {:ok, slot} =
      Scheduling.create_appointment_slot(
        prof.id,
        ~U[2026-04-10 14:00:00Z],
        ~U[2026-04-10 14:30:00Z]
      )

    Scheduling.book_appointment(slot.id, student.id, student.id)

    appointments = Scheduling.list_student_appointments(student.id)

    assert length(appointments) == 1
    assert hd(appointments).student_id == student.id
  end

  test "list_professional_appointments/1 lists professional schedule", %{prof: prof} do
    Scheduling.create_appointment_slot(
      prof.id,
      ~U[2026-04-10 15:00:00Z],
      ~U[2026-04-10 15:30:00Z]
    )

    Scheduling.create_appointment_slot(
      prof.id,
      ~U[2026-04-10 15:30:00Z],
      ~U[2026-04-10 16:00:00Z]
    )

    appointments = Scheduling.list_professional_appointments(prof.id)

    assert length(appointments) == 2
  end

  test "generate_availability/6 creates availability slots", %{prof: prof} do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 2)

    {:ok, slots} = Scheduling.generate_availability(prof.id, start_date, end_date, 30, 9, 12)

    assert length(slots) > 0
    assert Enum.all?(slots, &(&1.status == "available"))
  end

  test "count_available_slots/1 counts slots", %{prof: prof} do
    start_date = Date.utc_today()
    end_date = Date.add(start_date, 1)

    Scheduling.generate_availability(prof.id, start_date, end_date, 30, 9, 12)
    count = Scheduling.count_available_slots(prof.id)

    assert count > 0
  end

  test "create_recurring_availability/7 generates blocks with gap for three weeks", %{prof: prof} do
    weekday = Date.day_of_week(Date.utc_today()) |> Integer.to_string()

    {:ok, inserted} =
      Scheduling.create_recurring_availability(
        prof.id,
        weekday,
        "08:00",
        "10:00",
        "30",
        "10",
        "weekly"
      )

    assert inserted == 9

    appointments = Scheduling.list_professional_appointments(prof.id)
    assert length(appointments) == 9
    assert Enum.all?(appointments, &(&1.status == "available"))
  end

  test "list_future_available_psychologist_appointments/0 only returns psychologist slots", %{
    prof: prof
  } do
    {:ok, psychiatrist} =
      Accounts.create_professional(%{
        "university_id" => "PSY-TST-#{System.unique_integer([:positive])}",
        "email" => "psychiatrist-tst-#{System.unique_integer([:positive])}@uni.edu",
        "first_name" => "Dr.",
        "last_name" => "Another",
        "role" => "psychiatrist"
      })

    future_date = Date.add(Date.utc_today(), 10)
    psych_start = DateTime.new!(future_date, Time.new!(9, 0, 0), "Etc/UTC")
    psych_end = DateTime.new!(future_date, Time.new!(9, 30, 0), "Etc/UTC")
    psych_start_2 = DateTime.new!(future_date, Time.new!(10, 0, 0), "Etc/UTC")
    psych_end_2 = DateTime.new!(future_date, Time.new!(10, 30, 0), "Etc/UTC")

    Scheduling.create_appointment_slot(prof.id, psych_start, psych_end)
    Scheduling.create_appointment_slot(psychiatrist.id, psych_start_2, psych_end_2)

    appointments = Scheduling.list_future_available_psychologist_appointments()

    assert length(appointments) == 1
    assert hd(appointments).professional_id == prof.id
    assert hd(appointments).professional.role == "psychologist"
  end
end
