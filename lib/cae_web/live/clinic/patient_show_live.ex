defmodule CaeWeb.Clinic.PatientShowLive do
  use CaeWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:student_id, params["student_id"])
     |> assign(:page_title, "Dashboard 360")
     |> assign(:current_scope, socket.assigns[:current_scope])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="p-6">
        <h2 class="text-2xl font-bold">Dashboard 360 del Paciente #{@student_id}</h2>
      </section>
    </Layouts.app>
    """
  end
end
