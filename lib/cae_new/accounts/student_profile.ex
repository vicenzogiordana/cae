defmodule CaeNew.Accounts.StudentProfile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "student_profiles" do
    field :file_number, :string
    field :address, :string
    field :career, :string
    field :current_year, :integer
    field :birth_date, :date
    field :emergency_contact_name, :string
    field :emergency_contact_phone, :string
    field :emergency_contact_relationship, :string

    belongs_to :user, CaeNew.Accounts.User, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a student profile.
  """
  def changeset(student_profile, attrs) do
    student_profile
    |> cast(attrs, [
      :file_number,
      :address,
      :career,
      :current_year,
      :birth_date,
      :emergency_contact_name,
      :emergency_contact_phone,
      :emergency_contact_relationship,
      :user_id
    ])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:file_number, message: "el número de expediente ya existe")
  end
end
