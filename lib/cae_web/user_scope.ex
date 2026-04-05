defmodule CaeWeb.UserScope do
  @moduledoc """
  LiveView on_mount helper that loads a lightweight scope for development role simulation.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:load_scope, params, _session, socket) do
    {:cont, assign(socket, :current_scope, scope_from_params(params))}
  end

  defp scope_from_params(params) do
    if Application.get_env(:cae, :dev_routes, false) do
      role = Map.get(params, "as")

      if role in ["student", "secretary", "psychologist", "psychiatrist", "psychopedagogue"] do
        %{
          user: %{
            role: role,
            is_admin: Map.get(params, "admin") in ["true", "1", "yes"],
            first_name: "Demo",
            last_name: String.capitalize(role),
            id: parse_id(Map.get(params, "user_id"))
          }
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp parse_id(nil), do: nil

  defp parse_id(value) when is_integer(value), do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_id(_), do: nil
end
