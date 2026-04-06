defmodule Cae.Repo.Migrations.CreateAppointmentCancellations do
  use Ecto.Migration

  def change do
    create table(:appointment_cancellations) do
      add :appointment_id, :integer, null: false
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :professional_id, references(:users, on_delete: :delete_all), null: false
      add :start_at, :utc_datetime, null: false
      add :end_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:appointment_cancellations, [:appointment_id])
    create index(:appointment_cancellations, [:student_id])
    create index(:appointment_cancellations, [:professional_id])
    create index(:appointment_cancellations, [:inserted_at])
  end
end
