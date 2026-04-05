defmodule CaeNew.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :university_id, :string, null: false
      add :email, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :role, :string, null: false
      add :is_admin, :boolean, default: false
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:university_id])
    create unique_index(:users, [:email])
  end
end
