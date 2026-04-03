defmodule CaeNewWeb.PageController do
  use CaeNewWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
