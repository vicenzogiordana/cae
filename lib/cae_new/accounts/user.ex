defmodule CaeNew.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :university_id, :string
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :role, :string
    field :is_admin, :boolean, default: false
    field :is_active, :boolean, default: true

    has_one :student_profile, CaeNew.Accounts.StudentProfile,
      foreign_key: :user_id,
      on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a user.

  Required fields: university_id, email, role
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:university_id, :email, :first_name, :last_name, :role, :is_admin, :is_active])
    |> validate_required([:university_id, :email, :role])
    |> unique_constraint(:university_id)
    |> unique_constraint(:email)
    |> validate_inclusion(:role, [
      "student",
      "secretary",
      "psychologist",
      "psychiatrist",
      "psychopedagogue"
    ])
  end

  @doc """
  Changeset specifically for student registration.
  """
  def student_changeset(user, attrs) do
    attrs_with_role =
      attrs
      |> Map.put("role", "student")
      |> Map.put("is_active", true)

    user
    |> changeset(attrs_with_role)
  end
end
