defmodule CaeWeb.PageController do
  use CaeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
