defmodule CaeNew.AccountsTest do
  use CaeNew.DataCase

  alias CaeNew.Accounts

  describe "register_student/2" do
    def valid_user_attrs do
      %{
        "university_id" => "U12345",
        "email" => "student@example.com",
        "first_name" => "Juan",
        "last_name" => "Pérez"
      }
    end

    def valid_profile_attrs do
      %{
        "file_number" => "EXP-001",
        "address" => "Calle Principal 123",
        "career" => "Ingeniería Informática",
        "current_year" => 2,
        "birth_date" => ~D[2002-05-15],
        "emergency_contact_name" => "María Pérez",
        "emergency_contact_phone" => "+34 600 000 000"
      }
    end

    test "register_student/2 creates both user and profile" do
      {:ok, result} = Accounts.register_student(valid_user_attrs(), valid_profile_attrs())

      assert result.user.university_id == "U12345"
      assert result.user.email == "student@example.com"
      assert result.user.role == "student"
      assert result.user.is_active == true

      assert result.profile.file_number == "EXP-001"
      assert result.profile.career == "Ingeniería Informática"
      assert result.profile.user_id == result.user.id
    end

    test "register_student/2 fails if user_attrs is invalid" do
      {:error, :user, changeset, _} =
        Accounts.register_student(%{"email" => "student@example.com"}, valid_profile_attrs())

      assert "can't be blank" in errors_on(changeset).university_id
    end

    test "register_student/2 with duplicate university_id fails" do
      # Create first student
      {:ok, _} = Accounts.register_student(valid_user_attrs(), valid_profile_attrs())

      # Try to create another with same university_id
      {:error, :user, changeset, _} =
        Accounts.register_student(valid_user_attrs(), valid_profile_attrs())

      assert "has already been taken" in errors_on(changeset).university_id
    end

    test "register_student/2 with empty profile attributes still works" do
      {:ok, result} = Accounts.register_student(valid_user_attrs(), %{})

      assert result.user.university_id == "U12345"
      assert is_nil(result.profile.file_number)
    end
  end

  describe "get_user_by/1" do
    test "get_user_by finds user by university_id" do
      user_attrs = %{
        "university_id" => "U999",
        "email" => "unique@example.com",
        "role" => "student"
      }

      {:ok, user} = Accounts.create_user(user_attrs)

      assert Accounts.get_user_by(%{university_id: "U999"}).id == user.id
    end

    test "get_user_by returns nil if user not found" do
      assert is_nil(Accounts.get_user_by(%{university_id: "nonexistent"}))
    end
  end

  describe "list_users_by_role/1" do
    test "lists all users with a specific role" do
      {:ok, user1} =
        Accounts.create_user(%{
          "university_id" => "PSYCH1",
          "email" => "psych1@uni.edu",
          "role" => "psychologist"
        })

      {:ok, user2} =
        Accounts.create_user(%{
          "university_id" => "PSYCH2",
          "email" => "psych2@uni.edu",
          "role" => "psychologist"
        })

      {:ok, _student} =
        Accounts.create_user(%{
          "university_id" => "STU1",
          "email" => "student1@uni.edu",
          "role" => "student"
        })

      psychologists = Accounts.list_users_by_role("psychologist")

      assert length(psychologists) >= 2
      assert Enum.any?(psychologists, fn u -> u.id == user1.id end)
      assert Enum.any?(psychologists, fn u -> u.id == user2.id end)
    end
  end

  describe "deactivate_user/1 and reactivate_user/1" do
    test "deactivates and reactivates a user" do
      {:ok, user} =
        Accounts.create_user(%{
          "university_id" => "DEACT1",
          "email" => "deactive@uni.edu",
          "role" => "student",
          "is_active" => true
        })

      {:ok, deactivated} = Accounts.deactivate_user(user)
      assert deactivated.is_active == false

      {:ok, reactivated} = Accounts.reactivate_user(deactivated)
      assert reactivated.is_active == true
    end
  end
end
