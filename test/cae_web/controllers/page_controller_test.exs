defmodule CaeWeb.PageControllerTest do
  use CaeWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "CAE"
    assert html =~ "app-shell-drawer"
  end
end
