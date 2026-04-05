defmodule CaeNew.MedicalRecordsSimpleTest do
  use CaeNew.DataCase

  alias CaeNew.MedicalRecords
  alias CaeNew.Accounts

  setup do
    {:ok, student_result} =
      Accounts.register_student(%{
        "university_id" => "STU-MRC-#{System.unique_integer()}",
        "email" => "student-mrc-#{System.unique_integer()}@uni.edu",
        "first_name" => "María",
        "last_name" => "López"
      })

    {:ok, prof} =
      Accounts.create_professional(%{
        "university_id" => "PROF-MRC-#{System.unique_integer()}",
        "email" => "prof-mrc-#{System.unique_integer()}@uni.edu",
        "first_name" => "Dra.",
        "last_name" => "Rodríguez",
        "role" => "psychologist"
      })

    {:ok, student: student_result.user, prof: prof}
  end

  test "create_diagnosis/1 creates a diagnosis", %{student: student, prof: prof} do
    {:ok, diagnosis} =
      MedicalRecords.create_diagnosis(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "name" => "Trastorno de Ansiedad Generalizada"
      })

    assert diagnosis.student_id == student.id
    assert diagnosis.professional_id == prof.id
    assert diagnosis.is_active == true
  end

  test "list_active_diagnoses/1 lists active diagnoses", %{student: student, prof: prof} do
    MedicalRecords.create_diagnosis(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "name" => "Depresión"
    })

    diagnoses = MedicalRecords.list_active_diagnoses(student.id)

    assert length(diagnoses) >= 1
    assert Enum.all?(diagnoses, &(&1.is_active == true))
  end

  test "deactivate_diagnosis/1 deactivates a diagnosis", %{student: student, prof: prof} do
    {:ok, diagnosis} =
      MedicalRecords.create_diagnosis(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "name" => "Fobia Social"
      })

    {:ok, deactivated} = MedicalRecords.deactivate_diagnosis(diagnosis)

    assert deactivated.is_active == false
  end

  test "create_medical_document/1 creates encrypted document", %{student: student, prof: prof} do
    {:ok, diagnosis} =
      MedicalRecords.create_diagnosis(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "name" => "Depresión Severa"
      })

    {:ok, doc} =
      MedicalRecords.create_medical_document(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "diagnosis_id" => diagnosis.id,
        "encrypted_description" => "Resonancia magnética",
        "encrypted_filename" => "RMN_2026.pdf",
        "file_path" => "/uploads/rmn_2026.pdf",
        "content_type" => "application/pdf",
        "category" => "imaging"
      })

    assert doc.category == "imaging"
    assert is_binary(doc.encrypted_description)
  end

  test "list_student_documents/1 lists documents", %{student: student, prof: prof} do
    {:ok, diagnosis} =
      MedicalRecords.create_diagnosis(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "name" => "Test Diagnosis"
      })

    MedicalRecords.create_medical_document(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "diagnosis_id" => diagnosis.id,
      "encrypted_description" => "Doc 1",
      "encrypted_filename" => "doc1.pdf",
      "file_path" => "/uploads/doc1.pdf",
      "content_type" => "application/pdf",
      "category" => "report"
    })

    docs = MedicalRecords.list_student_documents(student.id)

    assert length(docs) >= 1
  end

  test "count_student_documents/1 counts documents", %{student: student, prof: prof} do
    {:ok, diagnosis} =
      MedicalRecords.create_diagnosis(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "name" => "Diagnosis"
      })

    MedicalRecords.create_medical_document(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "diagnosis_id" => diagnosis.id,
      "encrypted_description" => "Doc",
      "encrypted_filename" => "doc.pdf",
      "file_path" => "/uploads/doc.pdf",
      "content_type" => "application/pdf",
      "category" => "report"
    })

    count = MedicalRecords.count_student_documents(student.id)

    assert count >= 1
  end

  test "create_clinical_note/1 creates encrypted note", %{student: student, prof: prof} do
    {:ok, note} =
      MedicalRecords.create_clinical_note(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "encrypted_content" => "<p>Sesión inicial</p>"
      })

    assert note.student_id == student.id
    assert is_binary(note.encrypted_content)
  end

  test "list_student_clinical_notes/1 lists notes", %{student: student, prof: prof} do
    MedicalRecords.create_clinical_note(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "encrypted_content" => "<p>Nota 1</p>"
    })

    notes = MedicalRecords.list_student_clinical_notes(student.id)

    assert length(notes) >= 1
  end

  test "list_professional_clinical_notes/1 lists professional notes", %{
    student: student,
    prof: prof
  } do
    MedicalRecords.create_clinical_note(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "encrypted_content" => "<p>Prof note</p>"
    })

    notes = MedicalRecords.list_professional_clinical_notes(prof.id)

    assert length(notes) >= 1
  end

  test "count_student_clinical_notes/1 counts notes", %{student: student, prof: prof} do
    MedicalRecords.create_clinical_note(%{
      "student_id" => student.id,
      "professional_id" => prof.id,
      "encrypted_content" => "<p>Note</p>"
    })

    count = MedicalRecords.count_student_clinical_notes(student.id)

    assert count >= 1
  end

  test "get_latest_clinical_note/1 retrieves latest", %{student: student, prof: prof} do
    {:ok, note1} =
      MedicalRecords.create_clinical_note(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "encrypted_content" => "<p>First</p>"
      })

    Process.sleep(1100)

    {:ok, note2} =
      MedicalRecords.create_clinical_note(%{
        "student_id" => student.id,
        "professional_id" => prof.id,
        "encrypted_content" => "<p>Latest</p>"
      })

    latest = MedicalRecords.get_latest_clinical_note(student.id)

    assert latest.id == note2.id
    assert latest.id != note1.id
  end
end
