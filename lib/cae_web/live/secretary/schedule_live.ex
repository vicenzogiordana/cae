defmodule CaeWeb.Secretary.ScheduleLive do
  use CaeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: "Agenda General", current_scope: socket.assigns[:current_scope])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="p-6">
        <h2 class="text-2xl font-bold">Agenda General de Secretaria</h2>
      </section>
    </Layouts.app>
    """
  end
end
