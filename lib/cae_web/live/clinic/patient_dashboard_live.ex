defmodule CaeWeb.Clinic.PatientDashboardLive do
  use CaeWeb, :live_view

  alias Cae.Accounts
  alias Cae.MedicalRecords

  @upload_accepts ~w(.pdf .png .jpg .jpeg .doc .docx)

  @impl true
  def mount(%{"student_id" => student_id}, _session, socket) do
    with {parsed_student_id, ""} <- Integer.parse(student_id),
         true <- parsed_student_id > 0,
         %Accounts.User{} = student <- Accounts.get_user_by(id: parsed_student_id),
         %Accounts.StudentProfile{} = student_profile <- Accounts.get_student_profile(student.id),
         true <- student.role == "student" do
      diagnoses = MedicalRecords.list_student_diagnoses(student.id, false)
      clinical_notes = MedicalRecords.list_student_clinical_notes(student.id)

      # Get current professional from socket (assumes authenticated)
      current_user = socket.assigns[:current_user]
      professional_id = if current_user, do: current_user.id, else: nil

      # Build form for new clinical note
      new_note_form =
        to_form(%{
          "content" => "",
          "student_id" => student.id,
          "professional_id" => professional_id
        })

      {:ok,
       socket
       |> assign(:page_title, "Dashboard 360")
       |> assign(:current_scope, socket.assigns[:current_scope])
       |> assign(:current_user, current_user)
       |> assign(:student_id, student.id)
       |> assign(:patient, build_patient(student, student_profile))
       |> assign(:diagnoses, diagnoses)
       |> assign(:month_groups, build_month_groups(clinical_notes))
       |> assign(:new_note_form, new_note_form)
       |> assign(:saving_note, false)
       |> assign(:show_note_drawer, false)
       |> assign(:show_old_history, false)
       |> allow_upload(:medical_document,
         accept: @upload_accepts,
         max_entries: 4,
         max_file_size: 10_000_000
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "No se encontró el alumno solicitado")
         |> push_navigate(to: ~p"/live/clinic/patients")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard 360")
     |> assign(:current_scope, socket.assigns[:current_scope])
     |> assign(:student_id, nil)
     |> assign(:patient, nil)
     |> assign(:diagnoses, [])
     |> assign(:month_groups, [])
     |> assign(:show_note_drawer, false)
     |> assign(:show_old_history, false)
     |> allow_upload(:medical_document,
       accept: @upload_accepts,
       max_entries: 4,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_event("open_drawer", _params, socket) do
    {:noreply, assign(socket, :show_note_drawer, true)}
  end

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, :show_note_drawer, false)}
  end

  @impl true
  def handle_event("toggle_old_history", _params, socket) do
    {:noreply, assign(socket, :show_old_history, !socket.assigns.show_old_history)}
  end

  @impl true
  def handle_event("validate_note", %{"content" => content}, socket) do
    form = to_form(%{"content" => content}, errors: [])
    {:noreply, assign(socket, :new_note_form, form)}
  end

  @impl true
  def handle_event("save_note", %{"content" => content}, socket) do
    if String.trim(content) == "" do
      form = to_form(%{"content" => content}, errors: [content: {"no puede estar vacío", []}])
      {:noreply, assign(socket, :new_note_form, form)}
    else
      socket = assign(socket, :saving_note, true)

      case MedicalRecords.create_clinical_note(%{
             "student_id" => socket.assigns.student_id,
             "professional_id" => socket.assigns.current_user.id,
             "encrypted_content" => content,
             "appointment_id" => nil
           }) do
        {:ok, _note} ->
          # Refresh clinical notes and rebuild timeline
          clinical_notes = MedicalRecords.list_student_clinical_notes(socket.assigns.student_id)

          {:noreply,
           socket
           |> assign(:month_groups, build_month_groups(clinical_notes))
           |> assign(
             :new_note_form,
             to_form(%{
               "content" => "",
               "student_id" => socket.assigns.student_id,
               "professional_id" => socket.assigns.current_user.id
             })
           )
           |> assign(:saving_note, false)
           |> assign(:show_note_drawer, false)
           |> put_flash(:info, "Nota clínica guardada exitosamente")}

        {:error, changeset} ->
          form = to_form(changeset)

          {:noreply,
           socket
           |> assign(:new_note_form, form)
           |> assign(:saving_note, false)
           |> put_flash(:error, "Error al guardar la nota clínica")}
      end
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :medical_document, ref)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 p-6">
        <div class="flex flex-col gap-2">
          <h2 class="text-3xl font-bold tracking-tight">Dashboard 360 del Paciente</h2>
          <p class="text-sm text-base-content/70">
            Historia clínica, diagnósticos, documentos y evolución por sesiones.
          </p>
        </div>

        <div class="space-y-6">
          <%!-- Patient info --%>

          <div class="card border border-base-content/10 bg-base-100 shadow-sm">
            <div class="card-body gap-6 p-6">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div class="space-y-3">
                  <div>
                    <p class="text-sm uppercase tracking-[0.2em] text-base-content/50">
                      Resumen clínico
                    </p>
                    <h3 class="text-2xl font-bold">{patient_full_name(@patient)}</h3>
                    <p class="text-sm text-base-content/60">
                      Legajo {patient_file_number(@patient)}
                    </p>
                  </div>

                  <div class="grid gap-3 sm:grid-cols-2">
                    <div class="rounded-2xl bg-base-200/50 p-4">
                      <p class="text-xs uppercase tracking-wide text-base-content/50">Carrera</p>
                      <p class="mt-1 text-sm font-semibold">{patient_career(@patient)}</p>
                    </div>

                    <div class="rounded-2xl bg-base-200/50 p-4">
                      <p class="text-xs uppercase tracking-wide text-base-content/50">
                        Contacto de emergencia
                      </p>
                      <p class="mt-1 text-sm font-semibold">
                        {patient_emergency_contact(@patient)}
                      </p>
                      <p class="text-xs text-base-content/60">
                        {patient_emergency_phone(@patient)}
                      </p>
                    </div>
                  </div>
                </div>

                <div class="max-w-sm rounded-2xl border border-base-content/10 bg-base-200/30 p-4">
                  <p class="text-xs uppercase tracking-wide text-base-content/50">Diagnósticos</p>
                  <div class="mt-3 flex flex-wrap gap-2">
                    <span :for={diagnosis <- @diagnoses} class="badge badge-soft badge-error">
                      {diagnosis.name}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Clinical timeline history --%>
          <div class="card border border-base-content/10 bg-base-100 shadow-sm">
            <div class="card-body gap-6 p-6">
              <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
                <div>
                  <p class="text-sm uppercase tracking-[0.2em] text-base-content/50">
                    Historia clínica
                  </p>
                  <h3 class="text-2xl font-bold">Línea de tiempo de evoluciones</h3>
                </div>
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:gap-3">
                  <p class="max-w-xl text-sm text-base-content/60">
                    Las sesiones más recientes se muestran abiertas y la historia antigua queda colapsada.
                  </p>
                  <button
                    type="button"
                    class="btn btn-primary btn-sm whitespace-nowrap"
                    phx-click="open_drawer"
                  >
                    <.icon name="hero-plus" class="size-4" /> Nueva nota
                  </button>
                </div>
              </div>
              <div :for={group <- Enum.take(@month_groups, 1)} class="space-y-4">
                <span class="mt-2 text-sm font-semibold text-base-content/60">
                  {group.month_label}
                </span>
                <ul class="timeline timeline-compact timeline-vertical">
                  <li :for={note <- group.notes}>
                    <div class="timeline-middle">
                      <div class="grid h-9 w-9 place-items-center rounded-full bg-success/10 text-success">
                        <.icon name="hero-check-circle" class="size-5" />
                      </div>
                    </div>

                    <div class="timeline-end mb-8 ml-4 w-full">
                      <div class="rounded-2xl border border-base-content/10 bg-base-200/20 p-4 shadow-sm">
                        <div class="flex flex-col gap-3">
                          <div class="flex flex-wrap items-center gap-3 text-xs text-base-content/60">
                            <span class="badge badge-soft badge-neutral">{note.note_kind}</span>
                            <span>{note.session_label}</span>
                          </div>

                          <p class="text-sm leading-6 text-base-content/80">{note.content}</p>

                          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                            <div class="flex items-center gap-3 rounded-2xl bg-base-100 p-3">
                              <div class="avatar">
                                <div class="w-11 rounded-full ring-2 ring-base-200">
                                  <img
                                    src={note.professional_avatar_url}
                                    alt={note.professional_name}
                                  />
                                </div>
                              </div>

                              <div>
                                <p class="text-sm font-semibold leading-tight">
                                  {note.professional_name}
                                </p>
                                <p class="text-xs text-base-content/60">
                                  {note.professional_role}
                                </p>
                              </div>
                            </div>

                            <button
                              :if={note.attachment_name}
                              type="button"
                              class="btn btn-sm btn-soft btn-secondary"
                            >
                              <span class="icon-[tabler--file-type-pdf] text-error"></span>
                              {note.attachment_name}
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </li>
                </ul>
              </div>

              <div
                :if={length(@month_groups) > 1}
                class="rounded-2xl border border-base-content/10 bg-base-100"
              >
                <button
                  type="button"
                  phx-click="toggle_old_history"
                  class="flex w-full cursor-pointer items-center justify-between px-6 py-3 text-base font-semibold"
                >
                  <span>Historia clínica antigua</span>
                  <.icon
                    name="hero-chevron-down"
                    class={[
                      "size-4 text-base-content/60 transition-transform",
                      @show_old_history && "rotate-180"
                    ]}
                  />
                </button>

                <div :if={@show_old_history}>
                  <div class="space-y-8 px-6 pb-4 pt-2">
                    <div :for={group <- Enum.drop(@month_groups, 1)} class="space-y-4">
                      <span class="mt-2 text-sm font-semibold text-base-content/60">
                        {group.month_label}
                      </span>
                      <ul class="timeline timeline-compact timeline-vertical">
                        <li :for={note <- group.notes}>
                          <div class="timeline-middle">
                            <div class="grid h-9 w-9 place-items-center rounded-full bg-base-200 text-base-content/60">
                              <.icon name="hero-document-text" class="size-5" />
                            </div>
                          </div>

                          <div class="timeline-end mb-8 ml-4 w-full">
                            <div class="rounded-2xl border border-base-content/10 bg-base-200/20 p-4 shadow-sm">
                              <div class="flex flex-col gap-3">
                                <div class="flex flex-wrap items-center gap-3 text-xs text-base-content/60">
                                  <span class="badge badge-soft badge-neutral">
                                    {note.note_kind}
                                  </span>
                                  <span>{note.session_label}</span>
                                </div>

                                <p class="text-sm leading-6 text-base-content/80">
                                  {note.content}
                                </p>

                                <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                                  <div class="flex items-center gap-3 rounded-2xl bg-base-100 p-3">
                                    <div class="avatar">
                                      <div class="w-11 rounded-full ring-2 ring-base-200">
                                        <img
                                          src={note.professional_avatar_url}
                                          alt={note.professional_name}
                                        />
                                      </div>
                                    </div>

                                    <div>
                                      <p class="text-sm font-semibold leading-tight">
                                        {note.professional_name}
                                      </p>
                                      <p class="text-xs text-base-content/60">
                                        {note.professional_role}
                                      </p>
                                    </div>
                                  </div>

                                  <button
                                    :if={note.attachment_name}
                                    type="button"
                                    class="btn btn-sm btn-soft btn-secondary"
                                  >
                                    <span class="icon-[tabler--file-type-pdf] text-error"></span>
                                    {note.attachment_name}
                                  </button>
                                </div>
                              </div>
                            </div>
                          </div>
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Phoenix Native Drawer for new clinical note --%>
      <%!-- Backdrop --%>
      <div
        :if={@show_note_drawer}
        id="new-note-drawer-backdrop"
        class="fixed inset-0 z-40 bg-transparent transition-opacity"
        phx-click="close_drawer"
      >
      </div>

      <%!-- Right sidebar panel --%>
      <div
        :if={@show_note_drawer}
        id="new-note-drawer"
        class="fixed top-16 bottom-0 right-0 w-full sm:w-96 md:w-[420px] z-50 bg-base-100 shadow-2xl overflow-hidden flex flex-col transition-transform"
      >
        <div class="flex items-center justify-between border-b border-base-content/10 px-6 py-4">
          <h3 class="text-lg font-semibold">Nueva evolución clínica</h3>
          <button
            type="button"
            class="btn btn-text btn-circle btn-sm"
            aria-label="Close"
            phx-click="close_drawer"
          >
            <span class="icon-[tabler--x] size-5"></span>
          </button>
        </div>
        <div class="flex-1 overflow-y-auto px-6 py-4">
          <form
            id="new-clinical-note-form"
            phx-submit="save_note"
            phx-change="validate_note"
            class="flex h-full flex-col gap-4"
          >
            <div class="flex min-h-0 flex-1 flex-col gap-2">
              <label for="note-content" class="block text-sm font-medium text-base-content">
                Contenido de la nota
              </label>

              <div
                id="note-rich-editor-wrapper"
                phx-hook="RichTextNoteEditor"
                phx-update="ignore"
                data-input-id="note-content"
                class="flex min-h-0 flex-1 flex-col gap-2"
              >
                <div
                  data-editor-shell
                  class="hidden min-h-0 flex-1 overflow-hidden rounded-lg border border-base-content/10"
                >
                  <div
                    data-editorjs-holder
                    class="min-h-0 flex-1 overflow-y-auto px-3 py-2"
                  >
                  </div>
                </div>

                <textarea
                  id="note-content"
                  name="content"
                  value={Phoenix.HTML.Form.input_value(@new_note_form, :content)}
                  placeholder="Describe la evolución del paciente, observaciones de la sesión, cambios detectados, tareas asignadas, etc."
                  class="textarea textarea-bordered textarea-sm h-full min-h-40 w-full resize-y focus:textarea-primary"
                  rows="8"
                />
              </div>
            </div>

            <%!-- Optional: Attach documents to this note --%>
            <details class="rounded-lg border border-base-content/10 bg-base-100">
              <summary class="flex cursor-pointer items-center justify-between px-4 py-3 font-medium text-base-content hover:bg-base-200/50">
                <span class="flex items-center gap-2">
                  <.icon name="hero-paperclip" class="size-4" /> Adjuntar documentos (opcional)
                </span>
                <.icon name="hero-chevron-down" class="size-4" />
              </summary>

              <div class="space-y-3 border-t border-base-content/10 px-4 py-3">
                <div
                  class="rounded-lg border border-dashed border-primary/30 bg-primary/5 p-3"
                  phx-drop-target={@uploads.medical_document.ref}
                >
                  <div class="flex flex-col gap-2">
                    <div class="space-y-1">
                      <p class="text-xs font-semibold">Arrastra archivos o selecciona</p>
                      <p class="text-xs text-base-content/60">PDF, Word, JPG o PNG</p>
                    </div>
                    <label
                      for={@uploads.medical_document.ref}
                      class="btn btn-sm btn-primary w-full"
                    >
                      <.icon name="hero-arrow-up-tray" class="size-4" /> Seleccionar archivos
                    </label>
                  </div>

                  <input
                    type="file"
                    id={@uploads.medical_document.ref}
                    hidden
                    multiple
                    accept=".pdf,.png,.jpg,.jpeg,.doc,.docx"
                  />
                </div>

                <div :if={@uploads.medical_document.entries != []} class="space-y-2">
                  <p class="text-xs font-semibold uppercase text-base-content/60">
                    Archivos seleccionados
                  </p>
                  <ul class="space-y-2">
                    <li
                      :for={entry <- @uploads.medical_document.entries}
                      class="flex items-center gap-2 rounded-lg bg-base-200/30 p-2"
                    >
                      <div class="flex-1 truncate">
                        <p class="text-xs font-medium">{entry.client_name}</p>
                        <progress
                          class="progress progress-xs w-full"
                          max="100"
                          value={entry.progress}
                        >
                          {entry.progress}%
                        </progress>
                      </div>
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        aria-label="Eliminar"
                      >
                        <.icon name="hero-x-mark" class="size-3" />
                      </button>
                    </li>
                  </ul>
                </div>
                <p class="text-xs text-base-content/60">
                  Los archivos se guardarán junto con la nota.
                </p>
              </div>
            </details>
          </form>
        </div>

        <%!-- Footer with action buttons --%>
        <div class="border-t border-base-content/10 bg-base-100 p-6">
          <div class="flex gap-3">
            <button
              type="button"
              class="btn btn-soft btn-secondary btn-sm flex-1"
              phx-click="close_drawer"
            >
              Cancelar
            </button>
            <button
              type="submit"
              form="new-clinical-note-form"
              class="btn btn-primary btn-sm flex-1"
              disabled={@saving_note}
            >
              <span :if={@saving_note} class="loading loading-spinner loading-xs"></span>
              <span>Guardar nota</span>
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp build_patient(student, student_profile) do
    %{
      id: student.id,
      full_name: student_full_name(student),
      file_number: student_profile.file_number || "-",
      career: student_profile.career || "-",
      emergency_contact_name: student_profile.emergency_contact_name || "-",
      emergency_contact_phone: student_profile.emergency_contact_phone || "-"
    }
  end

  defp build_month_groups(notes) do
    notes
    |> Enum.map(&enrich_clinical_note/1)
    |> Enum.sort_by(& &1.session_at, {:desc, NaiveDateTime})
    |> Enum.group_by(&month_label/1)
    |> Enum.map(fn {month_label_value, month_notes} ->
      %{
        month_label: month_label_value,
        notes: Enum.sort_by(month_notes, & &1.session_at, {:desc, NaiveDateTime})
      }
    end)
    |> Enum.sort_by(
      fn group -> group.notes |> List.first() |> Map.fetch!(:session_at) end,
      {:desc, NaiveDateTime}
    )
  end

  defp enrich_clinical_note(note) do
    content = note.encrypted_content |> normalize_note_content()
    {note_content, attachment_name} = extract_attachment_name(content)
    professional_name = professional_display_name(note.professional)

    %{
      id: note.id,
      session_at: note.inserted_at,
      session_label: format_session_datetime(note.inserted_at),
      note_kind: "Evolución clínica",
      content: note_content,
      professional_name: professional_name,
      professional_role: professional_role_label(note.professional),
      professional_avatar_url: avatar_url(professional_name),
      attachment_name: attachment_name
    }
  end

  defp month_label(%{session_at: session_at}) do
    month_name =
      case session_at.month do
        1 -> "Enero"
        2 -> "Febrero"
        3 -> "Marzo"
        4 -> "Abril"
        5 -> "Mayo"
        6 -> "Junio"
        7 -> "Julio"
        8 -> "Agosto"
        9 -> "Septiembre"
        10 -> "Octubre"
        11 -> "Noviembre"
        12 -> "Diciembre"
      end

    "#{month_name} #{session_at.year}"
  end

  defp normalize_note_content(content) when is_binary(content), do: String.trim(content)
  defp normalize_note_content(content), do: content |> to_string() |> String.trim()

  defp extract_attachment_name(content) when is_binary(content) do
    case Regex.run(~r/\[adjunto:\s*([^\]]+)\]/u, content) do
      [_, attachment_name] ->
        cleaned = Regex.replace(~r/\s*\[adjunto:\s*[^\]]+\]/u, content, "") |> String.trim()
        {cleaned, String.trim(attachment_name)}

      _ ->
        {String.trim(content), nil}
    end
  end

  defp format_session_datetime(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")

  defp format_session_datetime(%NaiveDateTime{} = datetime),
    do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")

  defp format_session_datetime(_), do: "-"

  defp professional_display_name(nil), do: "Profesional"

  defp professional_display_name(professional) when is_map(professional) do
    cond do
      is_binary(professional.first_name) and is_binary(professional.last_name) ->
        "#{professional.first_name} #{professional.last_name}"

      is_binary(professional.email) ->
        professional.email

      true ->
        "Profesional"
    end
  end

  defp professional_role_label(nil), do: "Profesional"
  defp professional_role_label(%{role: "psychologist"}), do: "Psicóloga"
  defp professional_role_label(%{role: "psychiatrist"}), do: "Psiquiatra"
  defp professional_role_label(%{role: "psychopedagogue"}), do: "Psicopedagoga"
  defp professional_role_label(_), do: "Profesional"

  defp student_full_name(student) do
    cond do
      is_binary(student.first_name) and is_binary(student.last_name) ->
        "#{student.first_name} #{student.last_name}"

      is_binary(student.first_name) ->
        student.first_name

      is_binary(student.last_name) ->
        student.last_name

      true ->
        "Paciente"
    end
  end

  defp avatar_url(name) do
    encoded_name = URI.encode(name)
    "https://ui-avatars.com/api/?name=#{encoded_name}&background=0F172A&color=FFFFFF&bold=true"
  end

  defp patient_full_name(patient), do: Map.get(patient, :full_name, "Paciente")
  defp patient_file_number(patient), do: Map.get(patient, :file_number, "-")
  defp patient_career(patient), do: Map.get(patient, :career, "-")
  defp patient_emergency_contact(patient), do: Map.get(patient, :emergency_contact_name, "-")
  defp patient_emergency_phone(patient), do: Map.get(patient, :emergency_contact_phone, "-")
end
