defmodule CaeWeb.Router do
  use CaeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CaeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CaeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/live", CaeWeb do
    pipe_through :browser

    live_session :student,
      on_mount: [{CaeWeb.UserScope, :load_scope}] do
      live "/student/dashboard", Student.DashboardLive
      live "/student/appointments", Student.AppointmentsLive
      live "/student/schedule", Student.BookAppointmentLive
    end

    live_session :clinic,
      on_mount: [{CaeWeb.UserScope, :load_scope}] do
      live "/clinic/schedule", Clinic.ScheduleLive
      live "/clinic/patients", Clinic.PatientsLive
      live "/clinic/patients/:student_id", Clinic.PatientShowLive
    end

    live_session :secretary,
      on_mount: [{CaeWeb.UserScope, :load_scope}] do
      live "/secretary/schedule", Secretary.ScheduleLive
      live "/secretary/students", Secretary.StudentsLive
    end
  end

  scope "/", CaeWeb do
    pipe_through :browser

    live_session :admin,
      on_mount: [{CaeWeb.UserScope, :load_scope}] do
      live "/admin/staff", Admin.StaffLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", CaeWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:cae, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CaeWeb.Telemetry
    end
  end
end
