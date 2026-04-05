defmodule CaeNew.MedicalRecords.MedicalDocument do
  use Ecto.Schema
  import Ecto.Changeset

  schema "medical_documents" do
    field :encrypted_description, :binary
    field :encrypted_filename, :binary
    field :file_path, :string
    field :content_type, :string
    field :category, :string

    belongs_to :student, CaeNew.Accounts.User, foreign_key: :student_id
    belongs_to :professional, CaeNew.Accounts.User, foreign_key: :professional_id
    belongs_to :diagnosis, CaeNew.MedicalRecords.Diagnosis, foreign_key: :diagnosis_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a medical document.

  Note: encrypted_description and encrypted_filename are automatically encrypted by Cloak.Ecto.
  """
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :student_id,
      :professional_id,
      :diagnosis_id,
      :encrypted_description,
      :encrypted_filename,
      :file_path,
      :content_type,
      :category
    ])
    |> validate_required([:student_id, :professional_id, :file_path])
    |> foreign_key_constraint(:student_id, message: "el alumno no existe")
    |> foreign_key_constraint(:professional_id, message: "el profesional no existe")
    |> foreign_key_constraint(:diagnosis_id, message: "el diagnóstico no existe")
  end

  @doc """
  Changeset helper for creating documents with plain text that will be encrypted.
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
