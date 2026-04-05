defmodule CaeNew.Repo.Migrations.CreateDiagnoses do
  use Ecto.Migration

  def change do
    create table(:diagnoses) do
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :professional_id, references(:users, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:diagnoses, [:student_id])
    create index(:diagnoses, [:professional_id])
    create index(:diagnoses, [:is_active])
  end
end
