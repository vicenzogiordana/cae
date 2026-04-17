alias Cae.Accounts
alias Cae.MedicalRecords
alias Cae.Repo
alias Cae.Scheduling.Appointment
alias Cae.Scheduling.AppointmentCancellation
alias Ecto.Adapters.SQL

IO.puts("Cleaning clinical and account tables...")

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

create_professional! = fn attrs ->
  {:ok, user} = Accounts.create_professional(attrs)
  user
end

create_secretary! = fn attrs ->
  {:ok, user} = Accounts.create_secretary(attrs)
  user
end

register_student! = fn user_attrs, profile_attrs ->
  {:ok, %{user: user, profile: profile}} = Accounts.register_student(user_attrs, profile_attrs)
  {user, profile}
end

dt = fn date, hour, minute ->
  DateTime.new!(date, Time.new!(hour, minute, 0), "Etc/UTC")
end

IO.puts("Creating staff users...")

psychologist =
  create_professional!.(%{
    "university_id" => "PROF-1001",
    "email" => "camila.torres@cae.test",
    "first_name" => "Camila",
    "last_name" => "Torres",
    "role" => "psychologist"
  })

psychiatrist =
  create_professional!.(%{
    "university_id" => "PROF-2001",
    "email" => "bruno.silva@cae.test",
    "first_name" => "Bruno",
    "last_name" => "Silva",
    "role" => "psychiatrist"
  })

psychopedagogue =
  create_professional!.(%{
    "university_id" => "PROF-3001",
    "email" => "valeria.arias@cae.test",
    "first_name" => "Valeria",
    "last_name" => "Arias",
    "role" => "psychopedagogue"
  })

secretary =
  create_secretary!.(%{
    university_id: "SEC-1001",
    email: "lucia.rios@cae.test",
    first_name: "Lucia",
    last_name: "Rios"
  })

IO.puts("Creating students and profiles...")

{sofia, _sofia_profile} =
  register_student!.(
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
      "emergency_contact_name" => "Laura Martinez",
      "emergency_contact_phone" => "11 3456-7890",
      "emergency_contact_relationship" => "Madre"
    }
  )

{tomas, _tomas_profile} =
  register_student!.(
    %{
      "university_id" => "LEG-2023-017",
      "email" => "tomas.perez@cae.test",
      "first_name" => "Tomás",
      "last_name" => "Pérez"
    },
    %{
      "file_number" => "LEG-2023-017",
      "career" => "Ingeniería en Sistemas",
      "current_year" => 2,
      "birth_date" => ~D[2003-05-09],
      "address" => "San Martin 445, Rosario",
      "emergency_contact_name" => "Marta Perez",
      "emergency_contact_phone" => "341 555-1800",
      "emergency_contact_relationship" => "Madre"
    }
  )

{julieta, _julieta_profile} =
  register_student!.(
    %{
      "university_id" => "LEG-2022-311",
      "email" => "julieta.gomez@cae.test",
      "first_name" => "Julieta",
      "last_name" => "Gómez"
    },
    %{
      "file_number" => "LEG-2022-311",
      "career" => "Arquitectura",
      "current_year" => 4,
      "birth_date" => ~D[2002-11-28],
      "address" => "Belgrano 820, Cordoba",
      "emergency_contact_name" => "Carlos Gomez",
      "emergency_contact_phone" => "351 444-9922",
      "emergency_contact_relationship" => "Padre"
    }
  )

IO.puts("Creating diagnoses and clinical notes...")

{:ok, anxiety} =
  MedicalRecords.create_diagnosis(%{
    "student_id" => sofia.id,
    "professional_id" => psychologist.id,
    "name" => "Ansiedad academica"
  })

{:ok, organization} =
  MedicalRecords.create_diagnosis(%{
    "student_id" => sofia.id,
    "professional_id" => psychologist.id,
    "name" => "Dificultades de organizacion"
  })

{:ok, _tomas_dx} =
  MedicalRecords.create_diagnosis(%{
    "student_id" => tomas.id,
    "professional_id" => psychopedagogue.id,
    "name" => "Tecnicas de estudio"
  })

notes = [
  %{
    student_id: sofia.id,
    professional_id: psychologist.id,
    content:
      "Se observa mejor manejo de ansiedad ante parciales. Se pauta seguimiento semanal.",
    inserted_at: ~U[2026-04-11 15:30:00Z]
  },
  %{
    student_id: sofia.id,
    professional_id: psychologist.id,
    content:
      "Se trabajan rutinas de estudio y orden de prioridades en calendario academico.",
    inserted_at: ~U[2026-04-03 10:00:00Z]
  },
  %{
    student_id: tomas.id,
    professional_id: psychopedagogue.id,
    content:
      "Plan de acompanamiento para metodos de resumen y preparacion de finales.",
    inserted_at: ~U[2026-03-18 11:45:00Z]
  }
]

Enum.each(notes, fn attrs ->
  {:ok, note} =
    MedicalRecords.create_clinical_note(%{
      "student_id" => attrs.student_id,
      "professional_id" => attrs.professional_id,
      "appointment_id" => nil,
      "encrypted_content" => attrs.content
    })

  SQL.query!(Repo, "UPDATE clinical_notes SET inserted_at = $1, updated_at = $2 WHERE id = $3", [
    attrs.inserted_at,
    attrs.inserted_at,
    note.id
  ])
end)

IO.puts("Creating appointments (available, booked and cancelled)...")

today = Date.utc_today()

appointment_specs = [
  # psychologist slots
  %{professional_id: psychologist.id, start_at: dt.(Date.add(today, 1), 9, 0), end_at: dt.(Date.add(today, 1), 9, 30), status: "available"},
  %{professional_id: psychologist.id, start_at: dt.(Date.add(today, 2), 10, 0), end_at: dt.(Date.add(today, 2), 10, 30), status: "booked", student_id: sofia.id, booked_by_id: sofia.id},
  %{professional_id: psychologist.id, start_at: dt.(Date.add(today, 5), 11, 0), end_at: dt.(Date.add(today, 5), 11, 30), status: "available"},

  # psychiatrist slots
  %{professional_id: psychiatrist.id, start_at: dt.(Date.add(today, 3), 14, 0), end_at: dt.(Date.add(today, 3), 14, 30), status: "available"},
  %{professional_id: psychiatrist.id, start_at: dt.(Date.add(today, 7), 15, 0), end_at: dt.(Date.add(today, 7), 15, 30), status: "booked", student_id: sofia.id, booked_by_id: psychologist.id},

  # psychopedagogue slots
  %{professional_id: psychopedagogue.id, start_at: dt.(Date.add(today, 4), 13, 0), end_at: dt.(Date.add(today, 4), 13, 30), status: "available"},
  %{professional_id: psychopedagogue.id, start_at: dt.(Date.add(today, 6), 16, 0), end_at: dt.(Date.add(today, 6), 16, 30), status: "booked", student_id: tomas.id, booked_by_id: secretary.id},

  # historical cancelled appointment
  %{professional_id: psychologist.id, start_at: dt.(Date.add(today, -10), 12, 0), end_at: dt.(Date.add(today, -10), 12, 30), status: "cancelled", student_id: julieta.id, booked_by_id: julieta.id}
]

appointments =
  Enum.map(appointment_specs, fn spec ->
    %Appointment{}
    |> Appointment.changeset(%{
      professional_id: spec.professional_id,
      student_id: Map.get(spec, :student_id),
      booked_by_id: Map.get(spec, :booked_by_id),
      start_at: spec.start_at,
      end_at: spec.end_at,
      status: spec.status
    })
    |> Repo.insert!()
  end)

cancelled = Enum.find(appointments, &(&1.status == "cancelled"))

if cancelled do
  %AppointmentCancellation{}
  |> AppointmentCancellation.changeset(%{
    appointment_id: cancelled.id,
    student_id: cancelled.student_id,
    professional_id: cancelled.professional_id,
    cancelled_by_role: "student",
    start_at: cancelled.start_at,
    end_at: cancelled.end_at
  })
  |> Repo.insert!()
end

IO.puts("Seeds completed successfully")

IO.inspect(%{
  users: Repo.aggregate(Cae.Accounts.User, :count),
  appointments: Repo.aggregate(Appointment, :count),
  diagnoses: Repo.aggregate(Cae.MedicalRecords.Diagnosis, :count),
  notes: Repo.aggregate(Cae.MedicalRecords.ClinicalNote, :count),
  highlighted_student: %{id: sofia.id, email: sofia.email, diagnosis_1: anxiety.name, diagnosis_2: organization.name}
})
