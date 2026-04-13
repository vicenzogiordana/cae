alias Cae.Accounts
alias Cae.MedicalRecords
alias Cae.Repo
alias Ecto.Adapters.SQL

IO.puts("Cleaning seeded clinical tables...")

SQL.query!(
  Repo,
  """
  TRUNCATE TABLE
  	appointment_cancellations,
  	clinical_notes,
  	medical_documents,
  	diagnoses,
  	student_profiles,
  	appointments,
  	users
  RESTART IDENTITY CASCADE
  """,
  []
)

IO.puts("Creating professional account...")

{:ok, professional} =
  Accounts.create_professional(%{
    "university_id" => "PROF-1001",
    "email" => "camila.torres@cae.test",
    "first_name" => "Camila",
    "last_name" => "Torres",
    "role" => "psychologist"
  })

IO.puts("Creating student account and profile...")

{:ok, %{user: student, profile: student_profile}} =
  Accounts.register_student(
    %{
      "university_id" => "LEG-2024-042",
      "email" => "sofia.martinez@cae.test",
      "first_name" => "Sofía",
      "last_name" => "Martínez"
    },
    %{
      "file_number" => "LEG-2024-042",
      "career" => "Psicopedagogía",
      "current_year" => 3,
      "birth_date" => ~D[2004-08-17],
      "address" => "Av. Corrientes 1234, CABA",
      "emergency_contact_name" => "Laura Martínez",
      "emergency_contact_phone" => "11 3456-7890",
      "emergency_contact_relationship" => "Madre"
    }
  )

IO.puts("Creating diagnoses...")

{:ok, anxiety} =
  MedicalRecords.create_diagnosis(%{
    "student_id" => student.id,
    "professional_id" => professional.id,
    "name" => "Ansiedad"
  })

{:ok, adhd} =
  MedicalRecords.create_diagnosis(%{
    "student_id" => student.id,
    "professional_id" => professional.id,
    "name" => "TDAH"
  })

IO.puts("Creating clinical notes with staggered timestamps...")

notes = [
  %{
    content:
      "Sesión de seguimiento: se observa mejoría en la organización de tareas y mejor tolerancia a consignas breves. [adjunto: seguimiento-abril-2026.pdf]",
    inserted_at: ~U[2026-04-11 15:30:00Z],
    updated_at: ~U[2026-04-11 15:30:00Z]
  },
  %{
    content:
      "Sesión de seguimiento: se refuerzan rutinas visuales, anticipación de cambios y pausas activas. [adjunto: rutinas-abril-2026.pdf]",
    inserted_at: ~U[2026-04-03 10:00:00Z],
    updated_at: ~U[2026-04-03 10:00:00Z]
  },
  %{
    content:
      "Control de avance intermedio: disminuye la evitación de tareas complejas y mejora la adherencia a acuerdos semanales.",
    inserted_at: ~U[2026-01-18 11:45:00Z],
    updated_at: ~U[2026-01-18 11:45:00Z]
  },
  %{
    content:
      "Primera entrevista de seguimiento: la familia consulta por dificultades atencionales y ansiedad ante evaluaciones.",
    inserted_at: ~U[2025-10-09 09:15:00Z],
    updated_at: ~U[2025-10-09 09:15:00Z]
  },
  %{
    content:
      "Registro histórico inicial: se acuerda trabajo interdisciplinario con escuela y estrategia de fragmentación de consignas. [adjunto: informe-historico-2025.pdf]",
    inserted_at: ~U[2025-03-22 14:20:00Z],
    updated_at: ~U[2025-03-22 14:20:00Z]
  }
]

Enum.each(Enum.with_index(notes, 1), fn {note_attrs, index} ->
  diagnosis = if rem(index, 2) == 0, do: anxiety, else: adhd

  {:ok, note} =
    MedicalRecords.create_clinical_note(%{
      "student_id" => student.id,
      "professional_id" => professional.id,
      "appointment_id" => nil,
      "encrypted_content" => note_attrs.content
    })

  SQL.query!(Repo, "UPDATE clinical_notes SET inserted_at = $1, updated_at = $2 WHERE id = $3", [
    note_attrs.inserted_at,
    note_attrs.updated_at,
    note.id
  ])

  IO.puts("Inserted note #{note.id} for diagnosis #{diagnosis.name}")
end)

IO.puts("Seeds completed successfully")

IO.inspect(%{
  professional_id: professional.id,
  student_id: student.id,
  profile_id: student_profile.id
})
