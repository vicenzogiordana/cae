defmodule Cae.Repo.Migrations.BackfillProfessionalCancellations do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO appointment_cancellations (
      appointment_id,
      student_id,
      professional_id,
      cancelled_by_role,
      start_at,
      end_at,
      inserted_at,
      updated_at
    )
    SELECT
      a.id,
      a.student_id,
      a.professional_id,
      'professional',
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
      )
    """)
  end

  def down do
    execute("DELETE FROM appointment_cancellations WHERE cancelled_by_role = 'professional'")
  end
end
