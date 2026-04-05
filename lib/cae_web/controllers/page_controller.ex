defmodule CaeWeb.PageController do
  use CaeWeb, :controller

  def home(conn, params) do
    current_scope = dev_scope_from_params(params)

    render(conn, :home, current_scope: current_scope)
  end

  # Dev helper: allows quick role simulation from query params.
  # Example: /?as=student or /?as=secretary&admin=true
  defp dev_scope_from_params(params) do
    if Application.get_env(:cae, :dev_routes, false) do
      role = Map.get(params, "as")

      if role in ["student", "secretary", "psychologist", "psychiatrist", "psychopedagogue"] do
        %{
          user: %{
            role: role,
            is_admin: Map.get(params, "admin") in ["true", "1", "yes"],
            first_name: "Demo",
            last_name: String.capitalize(role)
          }
        }
      else
        nil
      end
    else
      nil
    end
  end
end
