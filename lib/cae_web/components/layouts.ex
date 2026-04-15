defmodule CaeWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CaeWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if is_nil(scope_user(@current_scope)) do %>
      <div class="relative min-h-screen w-screen overflow-x-hidden bg-slate-50">
        <input id="app-shell-drawer" type="checkbox" class="sr-only" />

        <header class="fixed inset-x-0 top-0 z-30 h-16 border-b border-slate-200 bg-white/95 px-4 backdrop-blur sm:px-6">
          <div class="mx-auto flex h-full w-full max-w-6xl items-center justify-between">
            <a href={~p"/"} class="text-xl font-extrabold tracking-wide text-slate-900">CAE</a>

            <.link href="/users/log_in" class="btn btn-primary btn-sm rounded-full px-5">
              Iniciar Sesion
            </.link>
          </div>
        </header>

        <div class="relative pt-16">
          <.flash_group flash={@flash} />

          <main class="min-h-[calc(100vh-4rem)] w-full min-w-0 px-0 py-0">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    <% else %>
      <div class="relative min-h-screen w-screen overflow-x-hidden bg-base-200/40">
        <input id="app-shell-drawer" type="checkbox" class="peer sr-only" />

        <header class="fixed inset-x-0 top-0 z-30 h-16 border-b border-base-content/25 bg-base-100 px-4 sm:px-6">
          <div class="navbar h-full p-0">
            <div class="flex-1">
              <label
                for="app-shell-drawer"
                aria-label="Abrir menu"
                class="inline-flex size-10 cursor-pointer items-center justify-center rounded-full border border-base-content/15 bg-base-100 text-base-content transition hover:bg-base-200"
              >
                <.icon name="hero-bars-3" class="size-6" />
              </label>
            </div>

            <div class="flex-1 text-center">
              <h1 class="text-4 font-extrabold tracking-wide sm:text-5">CAE</h1>
            </div>

            <div class="flex flex-1 items-center justify-end gap-2 sm:gap-3">
              <details class="relative">
                <summary class="inline-flex size-10 cursor-pointer list-none items-center justify-center rounded-full border border-base-content/15 bg-base-100 text-base-content transition hover:bg-base-200 [&::-webkit-details-marker]:hidden">
                  <span class="indicator">
                    <.icon name="hero-bell" class="size-5" />
                    <span class="indicator-item badge badge-primary badge-xs">3</span>
                  </span>
                </summary>
                <div class="absolute right-0 top-full z-50 mt-2 w-72 rounded-box border border-base-content/10 bg-base-100 shadow-sm">
                  <div class="p-3">
                    <p class="text-sm font-semibold">Notificaciones</p>
                    <p class="mt-1 text-sm text-base-content/70">
                      No hay alertas clinicas pendientes.
                    </p>
                  </div>
                </div>
              </details>

              <details class="relative">
                <summary class="inline-flex size-10 cursor-pointer list-none items-center justify-center rounded-full border border-base-content/15 bg-base-100 text-base-content transition hover:bg-base-200 [&::-webkit-details-marker]:hidden">
                  <div class="avatar">
                    <div class="size-9 rounded-full bg-primary/15 text-primary">
                      <span class="grid h-full place-items-center text-xs font-semibold">
                        {user_initials(@current_scope)}
                      </span>
                    </div>
                  </div>
                </summary>

                <ul class="menu absolute right-0 top-full z-50 mt-2 w-60 rounded-box border border-base-content/10 bg-base-100 p-2 shadow-sm">
                  <li class="menu-title px-2 py-1.5">
                    <span class="truncate text-xs">{display_name(@current_scope)}</span>
                  </li>
                  <li>
                    <.link navigate={~p"/"}>Mi perfil</.link>
                  </li>
                  <li>
                    <.link navigate={~p"/"}>Cerrar sesion</.link>
                  </li>
                </ul>
              </details>
            </div>
          </div>
        </header>

        <label
          for="app-shell-drawer"
          aria-label="Cerrar menu"
          class="pointer-events-none fixed inset-0 z-40 bg-black/25 opacity-0 transition peer-checked:pointer-events-auto peer-checked:opacity-100"
        >
        </label>

        <aside class="fixed inset-y-0 left-0 z-50 h-screen w-72 -translate-x-full border-r border-base-content/10 bg-base-100 transition-transform duration-300 ease-out peer-checked:translate-x-0">
          <div class="flex h-16 items-center gap-3 border-b border-base-200 px-4">
            <img src={~p"/images/logo.svg"} alt="CAE" class="size-8" />
            <div>
              <p class="text-sm font-semibold tracking-wide">CAE</p>
              <p class="text-xs text-base-content/60">Plataforma clinica</p>
            </div>
          </div>

          <nav class="p-3">
            <ul class="menu w-full gap-1 rounded-box">
              <%= for item <- menu_items(@current_scope) do %>
                <li>
                  <.link navigate={item.path} class="gap-2">
                    <.icon name={item.icon} class="size-4" />
                    <span>{item.label}</span>
                  </.link>
                </li>
              <% end %>

              <%= if admin?(@current_scope) do %>
                <li class="menu-title mt-4">
                  <span>Administracion</span>
                </li>
                <li>
                  <.link navigate={~p"/admin/staff"} class="gap-2">
                    <.icon name="hero-shield-check" class="size-4" />
                    <span>Gestion del Staff</span>
                  </.link>
                </li>
              <% end %>
            </ul>
          </nav>
        </aside>

        <div class="relative pt-16">
          <.flash_group flash={@flash} />

          <main class="min-h-[calc(100vh-4rem)] w-full min-w-0 px-0 py-0">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    <% end %>
    """
  end

  defp menu_items(current_scope) do
    role = role_from_scope(current_scope)

    common = [
      %{label: "Inicio", path: ~p"/", icon: "hero-home"}
    ]

    role_items =
      case role do
        "student" ->
          [
            %{label: "Inicio", path: ~p"/live/student/dashboard", icon: "hero-home"},
            %{
              label: "Mis Turnos",
              path: ~p"/live/student/appointments",
              icon: "hero-calendar-days"
            },
            %{
              label: "Sacar Turno",
              path: ~p"/live/student/schedule",
              icon: "hero-plus-circle"
            }
          ]

        "psychologist" ->
          [
            %{label: "Mi Agenda", path: ~p"/live/clinic/schedule", icon: "hero-calendar-days"},
            %{label: "Pacientes", path: ~p"/live/clinic/patients", icon: "hero-users"}
          ]

        "psychiatrist" ->
          [
            %{label: "Mi Agenda", path: ~p"/live/clinic/schedule", icon: "hero-calendar-days"},
            %{label: "Pacientes", path: ~p"/live/clinic/patients", icon: "hero-users"}
          ]

        "psychopedagogue" ->
          [
            %{label: "Mi Agenda", path: ~p"/live/clinic/schedule", icon: "hero-calendar-days"},
            %{label: "Pacientes", path: ~p"/live/clinic/patients", icon: "hero-users"}
          ]

        "secretary" ->
          [
            %{
              label: "Agenda General",
              path: ~p"/live/secretary/schedule",
              icon: "hero-calendar-days"
            },
            %{
              label: "Directorio y Gestion",
              path: ~p"/live/secretary/students",
              icon: "hero-clipboard-document-list"
            }
          ]

        _ ->
          []
      end

    common ++ role_items
  end

  defp admin?(current_scope) do
    user = scope_user(current_scope)
    value = user && (Map.get(user, :is_admin) || Map.get(user, "is_admin"))
    value == true
  end

  defp display_name(current_scope) do
    user = scope_user(current_scope)

    cond do
      is_nil(user) -> "Invitado"
      is_binary(Map.get(user, :full_name)) -> Map.get(user, :full_name)
      is_binary(Map.get(user, "full_name")) -> Map.get(user, "full_name")
      is_binary(Map.get(user, :name)) -> Map.get(user, :name)
      is_binary(Map.get(user, "name")) -> Map.get(user, "name")
      is_binary(Map.get(user, :email)) -> Map.get(user, :email)
      is_binary(Map.get(user, "email")) -> Map.get(user, "email")
      true -> "Usuario"
    end
  end

  defp user_initials(current_scope) do
    name = display_name(current_scope)

    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(fn part -> part |> String.first() |> String.upcase() end)
    |> Enum.join()
    |> case do
      "" -> "US"
      initials -> initials
    end
  end

  defp role_from_scope(current_scope) do
    user = scope_user(current_scope)
    role = user && (Map.get(user, :role) || Map.get(user, "role"))

    cond do
      is_binary(role) -> role
      is_atom(role) -> Atom.to_string(role)
      true -> nil
    end
  end

  defp scope_user(nil), do: nil

  defp scope_user(current_scope) when is_map(current_scope) do
    Map.get(current_scope, :user) ||
      Map.get(current_scope, "user") ||
      Map.get(current_scope, :current_user) ||
      Map.get(current_scope, "current_user")
  end

  defp scope_user(_), do: nil

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
