defmodule CaeNew.MedicalRecords do
  @moduledoc """
  The MedicalRecords context manages sensitive clinical data with encryption.

  This context handles:
  - Diagnoses (encrypted medical diagnoses)
  - Medical Documents (encrypted PDFs, reports, etc. with Cloak.Ecto)
  - Clinical Notes (encrypted session notes in HTML/plain text with Cloak.Ecto)

  All sensitive fields are automatically encrypted using AES-GCM via Cloak.Ecto.
  Direct database access to encrypted fields will show binary gibberish.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, warn: false
  alias CaeNew.Repo
  alias CaeNew.MedicalRecords.Diagnosis
  alias CaeNew.MedicalRecords.MedicalDocument
  alias CaeNew.MedicalRecords.ClinicalNote

  # ==================== DIAGNOSES ====================

  @doc """
  Gets a single diagnosis by id.

  Raises `Ecto.NoResultsError` if the Diagnosis does not exist.
  """
  def get_diagnosis!(id) do
    Diagnosis
    |> preload([:student, :professional, :medical_documents])
    |> Repo.get!(id)
  end

  @doc """
  Gets a diagnosis by id.

  Returns nil if the Diagnosis does not exist.
  """
  def get_diagnosis(id) do
    Diagnosis
    |> preload([:student, :professional, :medical_documents])
    |> Repo.get(id)
  end

  @doc """
  Lists all diagnoses for a student.
  """
  def list_student_diagnoses(student_id, only_active \\ true) do
    query =
      from(d in Diagnosis,
        where: d.student_id == ^student_id,
        preload: [:student, :professional, :medical_documents],
        order_by: [desc: d.inserted_at]
      )

    query =
      if only_active do
        from(d in query, where: d.is_active == true)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists all active diagnoses for a student.
  """
  def list_active_diagnoses(student_id) do
    list_student_diagnoses(student_id, true)
  end

  @doc """
  Creates a diagnosis.

  ## Examples

      iex> create_diagnosis(%{
      ...>   "student_id" => 1,
      ...>   "professional_id" => 5,
      ...>   "name" => "Ansiedad Generalizada"
      ... })
      {:ok, %Diagnosis{}}

  """
  def create_diagnosis(attrs) do
    %Diagnosis{}
    |> Diagnosis.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a diagnosis.
  """
  def update_diagnosis(%Diagnosis{} = diagnosis, attrs) do
    diagnosis
    |> Diagnosis.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deactivates a diagnosis (soft delete).
  """
  def deactivate_diagnosis(%Diagnosis{} = diagnosis) do
    diagnosis
    |> Diagnosis.deactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Reactivates a diagnosis.
  """
  def reactivate_diagnosis(%Diagnosis{} = diagnosis) do
    diagnosis
    |> Diagnosis.reactivate_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a diagnosis permanently.
  """
  def delete_diagnosis(%Diagnosis{} = diagnosis) do
    Repo.delete(diagnosis)
  end

  # ==================== MEDICAL DOCUMENTS ====================

  @doc """
  Gets a single medical document by id.

  Raises `Ecto.NoResultsError` if the Document does not exist.
  """
  def get_medical_document!(id) do
    MedicalDocument
    |> preload([:student, :professional, :diagnosis])
    |> Repo.get!(id)
  end

  @doc """
  Gets a medical document by id.

  Returns nil if the Document does not exist.
  """
  def get_medical_document(id) do
    MedicalDocument
    |> preload([:student, :professional, :diagnosis])
    |> Repo.get(id)
  end

  @doc """
  Lists all medical documents for a student.

  Optionally filters by category.
  """
  def list_student_documents(student_id, category \\ nil) do
    query =
      from(d in MedicalDocument,
        where: d.student_id == ^student_id,
        preload: [:student, :professional, :diagnosis],
        order_by: [desc: d.inserted_at]
      )

    query =
      if category do
        from(d in query, where: d.category == ^category)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists all medical documents for a student by category.
  """
  def list_documents_by_category(student_id, category) do
    list_student_documents(student_id, category)
  end

  @doc """
  Lists documents by diagnosis.
  """
  def list_documents_by_diagnosis(diagnosis_id) do
    MedicalDocument
    |> where([d], d.diagnosis_id == ^diagnosis_id)
    |> preload([:student, :professional, :diagnosis])
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a medical document.

  The encrypted_description and encrypted_filename will be automatically encrypted.

  ## Examples

      iex> create_medical_document(%{
      ...>   "student_id" => 1,
      ...>   "professional_id" => 5,
      ...>   "diagnosis_id" => 2,
      ...>   "encrypted_description" => "Resonancia magnética de cabeza",
      ...>   "encrypted_filename" => "resonancia_2026_04_03.pdf",
      ...>   "file_path" => "/uploads/documents/resonancia_2026_04_03.pdf",
      ...>   "content_type" => "application/pdf",
      ...>   "category" => "imaging"
      ... })
      {:ok, %MedicalDocument{}}

  """
  def create_medical_document(attrs) do
    %MedicalDocument{}
    |> MedicalDocument.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a medical document.
  """
  def update_medical_document(%MedicalDocument{} = document, attrs) do
    document
    |> MedicalDocument.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a medical document.
  """
  def delete_medical_document(%MedicalDocument{} = document) do
    Repo.delete(document)
  end

  # ==================== CLINICAL NOTES ====================

  @doc """
  Gets a single clinical note by id.

  Raises `Ecto.NoResultsError` if the Note does not exist.
  """
  def get_clinical_note!(id) do
    ClinicalNote
    |> preload([:student, :professional, :appointment])
    |> Repo.get!(id)
  end

  @doc """
  Gets a clinical note by id.

  Returns nil if the Note does not exist.
  """
  def get_clinical_note(id) do
    ClinicalNote
    |> preload([:student, :professional, :appointment])
    |> Repo.get(id)
  end

  @doc """
  Lists all clinical notes for a student.
  """
  def list_student_clinical_notes(student_id) do
    ClinicalNote
    |> where([n], n.student_id == ^student_id)
    |> preload([:student, :professional, :appointment])
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all clinical notes by professional (their session notes).
  """
  def list_professional_clinical_notes(professional_id) do
    ClinicalNote
    |> where([n], n.professional_id == ^professional_id)
    |> preload([:student, :professional, :appointment])
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists clinical notes for an appointment.
  """
  def list_appointment_clinical_notes(appointment_id) do
    ClinicalNote
    |> where([n], n.appointment_id == ^appointment_id)
    |> preload([:student, :professional, :appointment])
    |> Repo.all()
  end

  @doc """
  Creates a clinical note.

  The encrypted_content will be automatically encrypted by Cloak.Ecto.

  ## Examples

      iex> create_clinical_note(%{
      ...>   "student_id" => 1,
      ...>   "professional_id" => 5,
      ...>   "appointment_id" => 10,
      ...>   "encrypted_content" => "<p>Sesión de evaluación inicial...</p>"
      ... })
      {:ok, %ClinicalNote{}}

  """
  def create_clinical_note(attrs) do
    %ClinicalNote{}
    |> ClinicalNote.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a clinical note.
  """
  def update_clinical_note(%ClinicalNote{} = note, attrs) do
    note
    |> ClinicalNote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a clinical note.

  ⚠️  Warning: This is a permanent delete. Consider soft deletes in production.
  """
  def delete_clinical_note(%ClinicalNote{} = note) do
    Repo.delete(note)
  end

  # ==================== STATISTICS & REPORTING ====================

  @doc """
  Counts total medical documents for a student.
  """
  def count_student_documents(student_id) do
    MedicalDocument
    |> where([d], d.student_id == ^student_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Counts total clinical notes for a student.
  """
  def count_student_clinical_notes(student_id) do
    ClinicalNote
    |> where([n], n.student_id == ^student_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets the most recent clinical note for a student.
  """
  def get_latest_clinical_note(student_id) do
    ClinicalNote
    |> where([n], n.student_id == ^student_id)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> preload([:student, :professional, :appointment])
    |> Repo.one()
  end
end
