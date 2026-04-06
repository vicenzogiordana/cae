defmodule Cae.Scheduling.AppointmentCancellation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appointment_cancellations" do
    field :appointment_id, :integer
    field :cancelled_by_role, :string
    field :start_at, :utc_datetime
    field :end_at, :utc_datetime

    belongs_to :student, Cae.Accounts.User, foreign_key: :student_id
    belongs_to :professional, Cae.Accounts.User, foreign_key: :professional_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for a cancelled appointment history record.
  """
  def changeset(cancellation, attrs) do
    cancellation
    |> cast(attrs, [
      :appointment_id,
      :student_id,
      :professional_id,
      :cancelled_by_role,
      :start_at,
      :end_at
    ])
    |> validate_required([
      :appointment_id,
      :student_id,
      :professional_id,
      :cancelled_by_role,
      :start_at,
      :end_at
    ])
    |> validate_inclusion(:cancelled_by_role, ["student", "professional", "unknown"])
    |> foreign_key_constraint(:student_id, message: "el alumno no existe")
    |> foreign_key_constraint(:professional_id, message: "el profesional no existe")
  end
end
