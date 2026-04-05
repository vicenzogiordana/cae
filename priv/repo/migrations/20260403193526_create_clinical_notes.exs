defmodule CaeNew.Repo.Migrations.CreateClinicalNotes do
  use Ecto.Migration

  def change do
    create table(:clinical_notes) do
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :professional_id, references(:users, on_delete: :restrict), null: false
      add :appointment_id, references(:appointments, on_delete: :nilify_all)
      add :encrypted_content, :binary, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:clinical_notes, [:student_id])
    create index(:clinical_notes, [:professional_id])
    create index(:clinical_notes, [:appointment_id])
  end
end
