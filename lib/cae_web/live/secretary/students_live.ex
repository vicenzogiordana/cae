defmodule CaeWeb.Secretary.StudentsLive do
  use CaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Directorio", current_scope: socket.assigns[:current_scope])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="p-6">
        <h2 class="text-2xl font-bold">Directorio y Gestion de Estudiantes</h2>
      </section>
    </Layouts.app>
    """
  end
end
