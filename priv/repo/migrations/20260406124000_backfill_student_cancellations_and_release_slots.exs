defmodule Cae.Repo.Migrations.BackfillStudentCancellationsAndReleaseSlots do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO appointment_cancellations (
      appointment_id,
      student_id,
      professional_id,
      start_at,
      end_at,
      inserted_at,
      updated_at
    )
    SELECT
      a.id,
      a.student_id,
      a.professional_id,
      a.start_at,
      a.end_at,
      COALESCE(a.updated_at, NOW()),
      COALESCE(a.updated_at, NOW())
    FROM appointments a
    WHERE a.status = 'cancelled'
      AND a.student_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM appointment_cancellations c
        WHERE c.appointment_id = a.id
          AND c.student_id = a.student_id
      )
    """)

    execute("""
    UPDATE appointments
    SET
      status = 'available',
      student_id = NULL,
      booked_by_id = NULL,
      updated_at = NOW()
    WHERE status = 'cancelled'
      AND student_id IS NOT NULL
    """)
  end

  def down do
    execute("""
    UPDATE appointments
    SET
      status = 'cancelled',
      student_id = c.student_id,
      booked_by_id = c.student_id,
      updated_at = NOW()
    FROM appointment_cancellations c
    WHERE appointments.id = c.appointment_id
    """)

    execute("DELETE FROM appointment_cancellations")
  end
end
