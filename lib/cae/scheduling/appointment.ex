defmodule Cae.Scheduling.Appointment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appointments" do
    field :start_at, :utc_datetime
    field :end_at, :utc_datetime
    field :status, :string, default: "available"

    belongs_to :professional, Cae.Accounts.User, foreign_key: :professional_id
    belongs_to :student, Cae.Accounts.User, foreign_key: :student_id
    belongs_to :booked_by, Cae.Accounts.User, foreign_key: :booked_by_id

    timestamps(type: :utc_datetime)
  end

  @statuses ["available", "booked", "cancelled"]

  @doc """
  Changeset for creating or updating an appointment.
  """
  def changeset(appointment, attrs) do
    appointment
    |> cast(attrs, [:professional_id, :student_id, :booked_by_id, :start_at, :end_at, :status])
    |> validate_required([:professional_id, :start_at, :end_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_times()
    |> foreign_key_constraint(:professional_id, message: "el profesional no existe")
    |> foreign_key_constraint(:student_id, message: "el alumno no existe")
    |> foreign_key_constraint(:booked_by_id, message: "el usuario que reserva no existe")
  end

  @doc """
  Changeset for booking an appointment (marking it as booked).
  """
  def book_changeset(appointment, attrs) do
    appointment
    |> changeset(attrs)
    |> put_change(:status, "booked")
    |> validate_required([:student_id, :booked_by_id])
  end

  @doc """
  Changeset for cancelling an appointment.
  """
  def cancel_changeset(appointment) do
    appointment
    |> change()
    |> put_change(:status, "cancelled")
  end

  defp validate_times(changeset) do
    start_at = get_field(changeset, :start_at)
    end_at = get_field(changeset, :end_at)

    if start_at && end_at do
      if DateTime.compare(start_at, end_at) == :lt do
        changeset
      else
        add_error(changeset, :end_at, "debe ser posterior a la hora de inicio")
      end
    else
      changeset
    end
  end
end
