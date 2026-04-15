defmodule Cae.Accounts do
  @moduledoc """
  The Accounts context manages user identity and student profiles following Domain-Driven Design (DDD).

  In this context, we handle:
  - User creation and validation (by university_id, email, and role)
  - Student profile management (one-to-one relationship with users)
  - Role-based access control (RBAC)
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, warn: false
  alias Cae.Repo
  alias Cae.Accounts.User
  alias Cae.Accounts.StudentProfile

  @doc """
  Gets a single user by id.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by field (e.g., by university_id or email).

  Returns nil if the User does not exist.
  """
  def get_user_by(attrs) do
    Repo.get_by(User, attrs)
  end

  @doc """
  Gets a student profile by user id.

  Returns nil if the StudentProfile does not exist.
  """
  def get_student_profile(user_id) do
    Repo.get_by(StudentProfile, user_id: user_id)
  end

  @doc """
  Creates a new user.

  ## Examples

      iex> create_user(%{"university_id" => "12345", "email" => "user@example.com", "role" => "student"})
      {:ok, %User{}}

      iex> create_user(%{"university_id" => nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user and its associated student profile (if exists).

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Registers a new student along with their profile.

  This function uses `Ecto.Multi` to ensure atomicity: either both the user
  and student profile are created, or neither is created.

  ## Parameters

  - `user_attrs`: Map with user attributes (university_id, email, first_name, last_name)
  - `profile_attrs`: Map with student profile attributes (file_number, address, career, etc.)

  ## Returns

  - `{:ok, %{user: user, profile: profile}}` on success
  - `{:error, step, changeset, _}` on failure (step is :user or :profile)

  ## Examples

      iex> register_student(
      ...>   %{"university_id" => "U123456", "email" => "student@uni.edu", "first_name" => "Juan"},
      ...>   %{"career" => "Ingeniería Informática", "file_number" => "EXP-123"}
      ... )
      {:ok, %{user: %User{}, profile: %StudentProfile{}}}

      iex> register_student(
      ...>   %{"university_id" => nil},
      ...>   %{"career" => "Ingeniería"}
      ... )
      {:error, :user, changeset, _}

  """
  def register_student(user_attrs, profile_attrs \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.student_changeset(%User{}, user_attrs))
    |> Ecto.Multi.insert(:profile, fn %{user: user} ->
      profile_attrs_with_user = Map.put(profile_attrs, "user_id", user.id)
      StudentProfile.changeset(%StudentProfile{}, profile_attrs_with_user)
    end)
    |> Repo.transaction()
  end

  # ==================== ADMIN/STAFF FUNCTIONS ====================

  @doc """
  Creates a professional account (psychologist, psychiatrist, psychopedagogue).

  ## Examples

      iex> create_professional(%{
      ...>   "university_id" => "PROF-001",
      ...>   "email" => "psych@uni.edu",
      ...>   "first_name" => "Dra.",
      ...>   "last_name" => "Pérez",
      ...>   "role" => "psychologist"
      ... })
      {:ok, %User{}}

  """
  def create_professional(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> validate_professional_role()
    |> Repo.insert()
  end

  defp validate_professional_role(changeset) do
    role = get_field(changeset, :role)

    if role in ["psychologist", "psychiatrist", "psychopedagogue"] do
      changeset
    else
      add_error(changeset, :role, "no es un rol de profesional válido")
    end
  end

  @doc """
  Creates a secretary account.

  ## Examples

      iex> create_secretary(%{
      ...>   "university_id" => "SEC-001",
      ...>   "email" => "secretary@uni.edu",
      ...>   "first_name" => "María",
      ...>   "role" => "secretary"
      ... })
      {:ok, %User{}}

  """
  def create_secretary(attrs \\ %{}) do
    %User{}
    |> User.changeset(Map.put(attrs, :role, "secretary"))
    |> Repo.insert()
  end

  @doc """
  Lists all users with a given role.

  ## Examples

      iex> list_users_by_role("psychologist")
      [%User{}, ...]

  """
  def list_users_by_role(role) do
    Repo.all(from(u in User, where: u.role == ^role))
  end

  @doc """
  Lists all active students with optional search filtering.

  Preloads StudentProfile for each student. If a search_query is provided,
  filters students by combined full name, file number, or contact phone.
  Search is case-insensitive, accent-insensitive, and supports multi-word
  queries like "Sofia M".

  ## Examples

      iex> list_students()
      [%User{student_profile: %StudentProfile{}}, ...]

      iex> list_students("García")
      [%User{student_profile: %StudentProfile{}}, ...]

  """
  def list_students(search_query \\ "") do
    base_query =
      from(u in User,
        left_join: p in StudentProfile,
        on: p.user_id == u.id,
        where: u.role == "student" and u.is_active == true,
        preload: [student_profile: p],
        order_by: [u.last_name, u.first_name],
        limit: 50
      )

    terms =
      search_query
      |> to_string()
      |> String.trim()
      |> String.split(" ", trim: true)

    query =
      Enum.reduce(terms, base_query, fn term, query ->
        wildcard = "%#{term}%"

        from([u, p] in query,
          where:
            fragment("unaccent(?) ILIKE unaccent(?)", u.first_name, ^wildcard) or
              fragment("unaccent(?) ILIKE unaccent(?)", u.last_name, ^wildcard) or
              fragment("unaccent(?) ILIKE unaccent(?)", p.file_number, ^wildcard)
        )
      end)

    Repo.all(query)
  end

  @doc """
  Lists all active users.
  """
  def list_active_users do
    Repo.all(from(u in User, where: u.is_active == true))
  end

  @doc """
  Deactivates a user (soft delete).
  """
  def deactivate_user(%User{} = user) do
    update_user(user, %{is_active: false})
  end

  @doc """
  Reactivates a deactivated user.
  """
  def reactivate_user(%User{} = user) do
    update_user(user, %{is_active: true})
  end

  @doc """
  Promotes a user to admin.
  """
  def promote_to_admin(%User{} = user) do
    update_user(user, %{is_admin: true})
  end

  @doc """
  Demotes a user from admin.
  """
  def demote_from_admin(%User{} = user) do
    update_user(user, %{is_admin: false})
  end
end
