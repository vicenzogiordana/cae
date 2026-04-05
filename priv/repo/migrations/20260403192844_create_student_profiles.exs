defmodule Cae.Repo.Migrations.CreateStudentProfiles do
  use Ecto.Migration

  def change do
    create table(:student_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :file_number, :string
      add :address, :string
      add :career, :string
      add :current_year, :integer
      add :birth_date, :date
      add :emergency_contact_name, :string
      add :emergency_contact_phone, :string
      add :emergency_contact_relationship, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:student_profiles, [:user_id])
    create unique_index(:student_profiles, [:file_number])
  end
end
