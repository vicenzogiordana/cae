defmodule Cae.Repo.Migrations.AddCancelledByRoleToAppointmentCancellations do
  use Ecto.Migration

  def change do
    alter table(:appointment_cancellations) do
      add :cancelled_by_role, :string, null: false, default: "unknown"
    end

    execute(
      "UPDATE appointment_cancellations SET cancelled_by_role = 'student' WHERE cancelled_by_role = 'unknown'"
    )

    create index(:appointment_cancellations, [:cancelled_by_role])
  end
end
