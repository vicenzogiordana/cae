defmodule Cae.Repo.Migrations.CreateAppointments do
  use Ecto.Migration

  def change do
    create table(:appointments) do
      add :professional_id, references(:users, on_delete: :delete_all), null: false
      add :student_id, references(:users, on_delete: :delete_all)
      add :booked_by_id, references(:users, on_delete: :restrict)
      add :start_at, :utc_datetime, null: false
      add :end_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "available"

      timestamps(type: :utc_datetime)
    end

    create index(:appointments, [:professional_id])
    create index(:appointments, [:student_id])
    create index(:appointments, [:booked_by_id])
    create index(:appointments, [:status])
    create index(:appointments, [:start_at])
  end
end
