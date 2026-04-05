defmodule CaeNew.SchedulingAppointmentTest do
  use CaeNew.DataCase

  alias CaeNew.Scheduling
  alias CaeNew.Accounts

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

  test "block_appointment/1 blocks a time slot", %{prof: prof} do
    {:ok, slot} =
      Scheduling.create_appointment_slot(
        prof.id,
        ~U[2026-04-10 13:00:00Z],
        ~U[2026-04-10 13:30:00Z]
      )

    {:ok, blocked} = Scheduling.block_appointment(slot.id)

    assert blocked.status == "blocked"
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
end
