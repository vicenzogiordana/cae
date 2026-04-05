defmodule CaeNew.Repo.Migrations.CreateMedicalDocuments do
  use Ecto.Migration

  def change do
    create table(:medical_documents) do
      add :student_id, references(:users, on_delete: :delete_all), null: false
      add :professional_id, references(:users, on_delete: :restrict), null: false
      add :diagnosis_id, references(:diagnoses, on_delete: :nilify_all)
      add :encrypted_description, :binary
      add :encrypted_filename, :binary
      add :file_path, :string, null: false
      add :content_type, :string
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create index(:medical_documents, [:student_id])
    create index(:medical_documents, [:professional_id])
    create index(:medical_documents, [:diagnosis_id])
    create index(:medical_documents, [:category])
  end
end
