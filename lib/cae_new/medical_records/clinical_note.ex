defmodule CaeNew.MedicalRecords.ClinicalNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clinical_notes" do
    field :encrypted_content, :binary

    belongs_to :student, CaeNew.Accounts.User, foreign_key: :student_id
    belongs_to :professional, CaeNew.Accounts.User, foreign_key: :professional_id
    belongs_to :appointment, CaeNew.Scheduling.Appointment, foreign_key: :appointment_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a clinical note.

  Note: encrypted_content is automatically encrypted by Cloak.Ecto when saved.
  The content can be plain text or HTML from a WYSIWYG editor.
  """
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:student_id, :professional_id, :appointment_id, :encrypted_content])
    |> validate_required([:student_id, :professional_id, :encrypted_content])
    |> foreign_key_constraint(:student_id, message: "el alumno no existe")
    |> foreign_key_constraint(:professional_id, message: "el profesional no existe")
    |> foreign_key_constraint(:appointment_id, message: "la cita no existe")
  end

  @doc """
  Changeset for creating a clinical note with content (HTML or plain text).
  """
  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
