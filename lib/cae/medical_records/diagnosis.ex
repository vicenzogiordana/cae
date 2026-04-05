defmodule Cae.MedicalRecords.Diagnosis do
  use Ecto.Schema
  import Ecto.Changeset

  schema "diagnoses" do
    field :name, :string
    field :is_active, :boolean, default: true

    belongs_to :student, Cae.Accounts.User, foreign_key: :student_id
    belongs_to :professional, Cae.Accounts.User, foreign_key: :professional_id
    has_many :medical_documents, Cae.MedicalRecords.MedicalDocument, foreign_key: :diagnosis_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a diagnosis.
  """
  def changeset(diagnosis, attrs) do
    diagnosis
    |> cast(attrs, [:student_id, :professional_id, :name, :is_active])
    |> validate_required([:student_id, :professional_id, :name])
    |> foreign_key_constraint(:student_id, message: "el alumno no existe")
    |> foreign_key_constraint(:professional_id, message: "el profesional no existe")
  end

  @doc """
  Changeset for deactivating a diagnosis.
  """
  def deactivate_changeset(diagnosis) do
    diagnosis
    |> change()
    |> put_change(:is_active, false)
  end

  @doc """
  Changeset for reactivating a diagnosis.
  """
  def reactivate_changeset(diagnosis) do
    diagnosis
    |> change()
    |> put_change(:is_active, true)
  end
end
