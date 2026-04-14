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
      diagnoses = MedicalRecords.list_student_diagnoses(student.id, true)
      clinical_notes = MedicalRecords.list_student_clinical_notes(student.id)
      current_scope = socket.assigns[:current_scope]
      current_professional = current_professional(current_scope)

      # Build form for new clinical note
      new_note_form =
        to_form(%{
          "content" => "",
          "diagnosis_name" => "",
          "diagnosis_id" => "",
          "deactivate_diagnosis" => "false",
          "student_id" => student.id,
          "professional_id" => current_professional && current_professional.id
        })

      {:ok,
       socket
       |> assign(:page_title, "Dashboard 360")
       |> assign(:current_scope, current_scope)
       |> assign(:current_user, current_professional)
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
  def handle_event("validate_note", %{"content" => content} = params, socket) do
    diagnosis_name = Map.get(params, "diagnosis_name", "")
    diagnosis_id = Map.get(params, "diagnosis_id", "")
    deactivate_diagnosis = Map.get(params, "deactivate_diagnosis", "false")

    form =
      to_form(
        %{
          "content" => content,
          "diagnosis_name" => diagnosis_name,
          "diagnosis_id" => diagnosis_id,
          "deactivate_diagnosis" => deactivate_diagnosis
        },
        errors: []
      )

    {:noreply, assign(socket, :new_note_form, form)}
  end

  @impl true
  def handle_event("save_note", %{"content" => content} = params, socket) do
    diagnosis_name = Map.get(params, "diagnosis_name", "")
    diagnosis_id = Map.get(params, "diagnosis_id", "")
    deactivate_diagnosis = Map.get(params, "deactivate_diagnosis", "false")
    professional = current_professional(socket.assigns.current_scope)
    professional_id = professional && professional.id

    if String.trim(content) == "" do
      form =
        to_form(
          %{
            "content" => content,
            "diagnosis_name" => diagnosis_name,
            "diagnosis_id" => diagnosis_id,
            "deactivate_diagnosis" => deactivate_diagnosis
          },
          errors: [content: {"no puede estar vacío", []}]
        )

      {:noreply, assign(socket, :new_note_form, form)}
    else
      socket = assign(socket, :saving_note, true)

      case MedicalRecords.create_clinical_note_with_optional_diagnosis(
             %{
               "student_id" => socket.assigns.student_id,
               "professional_id" => professional_id,
               "encrypted_content" => content,
               "appointment_id" => nil
             },
             %{
               "diagnosis_name" => diagnosis_name,
               "diagnosis_id" => diagnosis_id,
               "deactivate_diagnosis" => deactivate_diagnosis
             }
           ) do
        {:ok, _note} ->
          # Refresh clinical notes and rebuild timeline
          clinical_notes = MedicalRecords.list_student_clinical_notes(socket.assigns.student_id)
          diagnoses = MedicalRecords.list_student_diagnoses(socket.assigns.student_id, true)

          {:noreply,
           socket
           |> assign(:month_groups, build_month_groups(clinical_notes))
           |> assign(:diagnoses, diagnoses)
           |> assign(
             :new_note_form,
             to_form(%{
               "content" => "",
               "diagnosis_name" => "",
               "diagnosis_id" => "",
               "deactivate_diagnosis" => "false",
               "student_id" => socket.assigns.student_id,
               "professional_id" => professional_id
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
                      <div class={[
                        "grid h-9 w-9 place-items-center rounded-full",
                        diagnosis_event_timeline_class(note.diagnosis_event, :recent)
                      ]}>
                        <.icon
                          name={diagnosis_event_timeline_icon(note.diagnosis_event, :recent)}
                          class="size-5"
                        />
                      </div>
                    </div>

                    <div class="timeline-end mb-8 ml-4 w-full">
                      <div class="rounded-2xl border border-base-content/10 bg-base-200/20 p-4 shadow-sm">
                        <div class="flex flex-col gap-3">
                          <div class="flex flex-wrap items-center gap-3 text-xs text-base-content/60">
                            <span class="badge badge-soft badge-neutral">{note.note_kind}</span>
                            <span
                              :if={note.diagnosis_event}
                              class={[
                                "badge badge-soft",
                                diagnosis_event_badge_class(note.diagnosis_event.action)
                              ]}
                            >
                              {diagnosis_event_label(note.diagnosis_event)}
                            </span>
                            <span>{note.session_label}</span>
                          </div>

                          <div class="editor-note-content text-sm leading-6 text-base-content/80">
                            {note.content_html}
                          </div>

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
                            <div class={[
                              "grid h-9 w-9 place-items-center rounded-full",
                              diagnosis_event_timeline_class(note.diagnosis_event, :old)
                            ]}>
                              <.icon
                                name={diagnosis_event_timeline_icon(note.diagnosis_event, :old)}
                                class="size-5"
                              />
                            </div>
                          </div>

                          <div class="timeline-end mb-8 ml-4 w-full">
                            <div class="rounded-2xl border border-base-content/10 bg-base-200/20 p-4 shadow-sm">
                              <div class="flex flex-col gap-3">
                                <div class="flex flex-wrap items-center gap-3 text-xs text-base-content/60">
                                  <span class="badge badge-soft badge-neutral">
                                    {note.note_kind}
                                  </span>
                                  <span
                                    :if={note.diagnosis_event}
                                    class={[
                                      "badge badge-soft",
                                      diagnosis_event_badge_class(note.diagnosis_event.action)
                                    ]}
                                  >
                                    {diagnosis_event_label(note.diagnosis_event)}
                                  </span>
                                  <span>{note.session_label}</span>
                                </div>

                                <div class="editor-note-content text-sm leading-6 text-base-content/80">
                                  {note.content_html}
                                </div>

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

              <div class="space-y-2">
                <select
                  id="diagnosis-id"
                  name="diagnosis_id"
                  class="select select-bordered select-sm w-full"
                >
                  <option value="">Crear nuevo diagnóstico</option>
                  <option
                    :for={diagnosis <- @diagnoses}
                    value={diagnosis.id}
                    selected={
                      to_string(diagnosis.id) ==
                        Phoenix.HTML.Form.input_value(@new_note_form, :diagnosis_id)
                    }
                  >
                    {diagnosis.name}
                  </option>
                </select>

                <div
                  :if={Phoenix.HTML.Form.input_value(@new_note_form, :diagnosis_id) in ["", nil]}
                  class="space-y-2"
                >
                  <label for="diagnosis-name" class="block text-sm font-medium text-base-content">
                    Diagnóstico (opcional)
                  </label>

                  <input
                    id="diagnosis-name"
                    name="diagnosis_name"
                    type="text"
                    value={Phoenix.HTML.Form.input_value(@new_note_form, :diagnosis_name)}
                    placeholder="Ej: Trastorno de ansiedad generalizada"
                    class="input input-bordered input-sm w-full"
                  />
                </div>

                <label class="label cursor-pointer justify-start gap-2">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    name="deactivate_diagnosis"
                    value="true"
                    checked={
                      Phoenix.HTML.Form.input_value(@new_note_form, :deactivate_diagnosis) in [
                        true,
                        "true",
                        "on",
                        "1"
                      ]
                    }
                  />
                  <span class="label-text">Desactivar diagnóstico seleccionado</span>
                </label>

                <p class="text-xs text-base-content/60">
                  Si seleccionas uno existente, el campo de nombre se oculta. Si activas desactivar, lo desactiva.
                  Si dejas el selector en "Crear nuevo diagnóstico", aparece el campo para cargar el nombre.
                </p>
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
    {note_content, diagnosis_event, attachment_name, content_html} = parse_note_content(content)
    professional_name = professional_display_name(note.professional)

    %{
      id: note.id,
      session_at: note.inserted_at,
      session_label: format_session_datetime(note.inserted_at),
      note_kind: "Evolución clínica",
      content: note_content,
      content_html: Phoenix.HTML.raw(content_html),
      diagnosis_event: diagnosis_event,
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

  defp current_professional(nil), do: first_available_professional(nil)

  defp current_professional(current_scope) when is_map(current_scope) do
    user =
      Map.get(current_scope, :user) ||
        Map.get(current_scope, "user") ||
        Map.get(current_scope, :current_user) ||
        Map.get(current_scope, "current_user")

    cond do
      is_map(user) and is_integer(Map.get(user, :id)) -> Accounts.get_user!(Map.get(user, :id))
      is_map(user) and is_integer(Map.get(user, "id")) -> Accounts.get_user!(Map.get(user, "id"))
      is_map(user) -> resolve_professional_from_scope_user(user)
      true -> nil
    end
  end

  defp current_professional(_), do: first_available_professional(nil)

  defp resolve_professional_from_scope_user(user) do
    role = scope_user_role(user)
    email = scope_user_email(user)
    first_name = scope_user_first_name(user)
    last_name = scope_user_last_name(user)
    full_name = Enum.join([first_name, last_name], " ") |> String.trim()

    candidate_by_email =
      if is_binary(email) and email != "" do
        Accounts.get_user_by(email: email)
      end

    candidate_by_name =
      if is_binary(role) and role != "" do
        Accounts.list_users_by_role(role)
        |> Enum.find(fn professional ->
          professional_full_name = professional_display_name(professional)

          professional_full_name == full_name or
            professional.first_name == first_name or
            professional.last_name == last_name
        end)
      end

    candidate_by_email || candidate_by_name || first_available_professional(role)
  end

  defp scope_user_role(user) do
    Map.get(user, :role) || Map.get(user, "role")
  end

  defp scope_user_email(user) do
    Map.get(user, :email) || Map.get(user, "email")
  end

  defp scope_user_first_name(user) do
    Map.get(user, :first_name) || Map.get(user, "first_name") || ""
  end

  defp scope_user_last_name(user) do
    Map.get(user, :last_name) || Map.get(user, "last_name") || ""
  end

  defp first_available_professional(role)
       when role in ["psychologist", "psychiatrist", "psychopedagogue"] do
    Accounts.list_users_by_role(role) |> List.first()
  end

  defp first_available_professional(_role) do
    ["psychologist", "psychiatrist", "psychopedagogue"]
    |> Enum.find_value(fn candidate_role ->
      Accounts.list_users_by_role(candidate_role) |> List.first()
    end)
  end

  defp parse_note_content(content) do
    content = to_string(content)

    case Jason.decode(content) do
      {:ok, payload} when is_map(payload) ->
        case Map.get(payload, "blocks") do
          blocks when is_list(blocks) ->
            diagnosis_event = parse_diagnosis_event_meta(Map.get(payload, "diagnosis_event"))
            rendered_html = render_editorjs_blocks(blocks)
            plain_text = render_editorjs_plain_text(blocks)

            {plain_text, diagnosis_event, nil, rendered_html}

          _ ->
            {content_without_markers, diagnosis_event} = extract_diagnosis_event(content)
            {cleaned_content, attachment_name} = extract_attachment_name(content_without_markers)
            html = render_plain_text_content(cleaned_content)

            {cleaned_content, diagnosis_event, attachment_name, html}
        end

      _ ->
        {content_without_markers, diagnosis_event} = extract_diagnosis_event(content)
        {cleaned_content, attachment_name} = extract_attachment_name(content_without_markers)
        html = render_plain_text_content(cleaned_content)

        {cleaned_content, diagnosis_event, attachment_name, html}
    end
  end

  defp render_editorjs_blocks(blocks) do
    blocks
    |> Enum.map_join("\n", &render_editorjs_block/1)
  end

  defp render_editorjs_plain_text(blocks) do
    blocks
    |> Enum.map(&editorjs_block_plain_text/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp render_editorjs_block(%{"type" => "header", "data" => data}) do
    level = data |> Map.get("level", 2) |> clamp_header_level()
    text = Map.get(data, "text", "") |> to_string()

    "<h#{level} class=\"font-bold tracking-tight text-base-content\">#{text}</h#{level}>"
  end

  defp render_editorjs_block(%{"type" => "paragraph", "data" => data}) do
    text = Map.get(data, "text", "") |> to_string() |> String.replace("\n", "<br>")

    "<p>#{text}</p>"
  end

  defp render_editorjs_block(%{"type" => "list", "data" => data}) do
    items = Map.get(data, "items", [])
    style = Map.get(data, "style", "unordered")
    tag = if style == "ordered", do: "ol", else: "ul"
    list_class = if style == "ordered", do: "list-decimal", else: "list-disc"

    items_html =
      items
      |> Enum.map_join("", fn item ->
        {item_text, nested_items} = parse_editorjs_list_item(item)

        nested_html =
          if nested_items == [],
            do: "",
            else:
              render_editorjs_block(%{
                "type" => "list",
                "data" => %{"style" => style, "items" => nested_items}
              })

        "<li>#{item_text}#{nested_html}</li>"
      end)

    "<#{tag} class=\"ml-6 #{list_class} space-y-1\">#{items_html}</#{tag}>"
  end

  defp render_editorjs_block(%{"type" => "warning", "data" => data}) do
    title = Map.get(data, "title", "Advertencia") |> to_string()
    message = Map.get(data, "message", "") |> to_string()

    """
    <div class=\"my-3 rounded-xl border border-warning/30 bg-warning/10 p-4\">
      <p class=\"font-semibold text-warning\">#{title}</p>
      <div class=\"mt-1\">#{message}</div>
    </div>
    """
  end

  defp render_editorjs_block(%{"type" => _type, "data" => data}) when is_map(data) do
    fallback = Map.get(data, "text", "") |> to_string() |> String.replace("\n", "<br>")

    if fallback == "" do
      ""
    else
      "<p>#{fallback}</p>"
    end
  end

  defp render_editorjs_block(_), do: ""

  defp editorjs_block_plain_text(%{"type" => "header", "data" => data}),
    do: Map.get(data, "text", "") |> to_string()

  defp editorjs_block_plain_text(%{"type" => "paragraph", "data" => data}),
    do: Map.get(data, "text", "") |> to_string()

  defp editorjs_block_plain_text(%{"type" => "warning", "data" => data}),
    do:
      [Map.get(data, "title", ""), Map.get(data, "message", "")]
      |> Enum.map_join(" ", &to_string/1)

  defp editorjs_block_plain_text(%{"type" => "list", "data" => data}),
    do: data |> Map.get("items", []) |> Enum.map_join("\n", &editorjs_list_item_plain_text/1)

  defp editorjs_block_plain_text(_), do: ""

  defp editorjs_list_item_plain_text(%{"content" => content}), do: to_string(content)
  defp editorjs_list_item_plain_text(%{"text" => text}), do: to_string(text)
  defp editorjs_list_item_plain_text(content), do: to_string(content)

  defp parse_editorjs_list_item(item) when is_map(item) do
    text = Map.get(item, "content", Map.get(item, "text", "")) |> to_string()
    nested_items = Map.get(item, "items", [])
    {text, nested_items}
  end

  defp parse_editorjs_list_item(item), do: {to_string(item), []}

  defp clamp_header_level(level) when level in 1..6, do: level
  defp clamp_header_level(_), do: 2

  defp render_plain_text_content(content) do
    content
    |> html_escape_preserving_breaks()
    |> then(&"<p>#{&1}</p>")
  end

  defp html_escape_preserving_breaks(content) do
    content
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("\n", "<br>")
  end

  defp parse_diagnosis_event_meta(
         %{"action" => action, "diagnosis_name" => diagnosis_name} = meta
       ) do
    %{
      action: to_string(action),
      diagnosis_name: to_string(diagnosis_name),
      diagnosis_id: Map.get(meta, "diagnosis_id")
    }
  end

  defp parse_diagnosis_event_meta(_), do: nil

  defp extract_attachment_name(content) when is_binary(content) do
    case Regex.run(~r/\[adjunto:\s*([^\]]+)\]/u, content) do
      [_, attachment_name] ->
        cleaned = Regex.replace(~r/\s*\[adjunto:\s*[^\]]+\]/u, content, "") |> String.trim()
        {cleaned, String.trim(attachment_name)}

      _ ->
        {String.trim(content), nil}
    end
  end

  defp extract_diagnosis_event(content) do
    content = to_string(content)
    regex = ~r/\[diagnostico_evento:\s*(created|updated|deactivated)\|([^\]]+)\]/u

    case Regex.run(regex, content) do
      [full_match, action, diagnosis_name] ->
        cleaned_content =
          content
          |> String.replace(full_match, "")
          |> String.trim()

        event = %{action: action, diagnosis_name: String.trim(diagnosis_name)}
        {cleaned_content, event}

      _ ->
        {content, nil}
    end
  end

  defp diagnosis_event_badge_class("created"), do: "badge-success"
  defp diagnosis_event_badge_class("updated"), do: "badge-info"
  defp diagnosis_event_badge_class("deactivated"), do: "badge-warning"
  defp diagnosis_event_badge_class(_), do: "badge-neutral"

  defp diagnosis_event_timeline_class(nil, :recent), do: "bg-success/10 text-success"
  defp diagnosis_event_timeline_class(nil, :old), do: "bg-base-200 text-base-content/60"

  defp diagnosis_event_timeline_class(%{action: "created"}, _section),
    do: "bg-success/10 text-success"

  defp diagnosis_event_timeline_class(%{action: "updated"}, _section), do: "bg-info/15 text-info"

  defp diagnosis_event_timeline_class(%{action: "deactivated"}, _section),
    do: "bg-warning/20 text-warning"

  defp diagnosis_event_timeline_class(_, :recent), do: "bg-success/10 text-success"
  defp diagnosis_event_timeline_class(_, :old), do: "bg-base-200 text-base-content/60"

  defp diagnosis_event_timeline_icon(nil, :recent), do: "hero-check-circle"
  defp diagnosis_event_timeline_icon(nil, :old), do: "hero-document-text"
  defp diagnosis_event_timeline_icon(%{action: "created"}, _section), do: "hero-check-circle"
  defp diagnosis_event_timeline_icon(%{action: "updated"}, _section), do: "hero-document-text"
  defp diagnosis_event_timeline_icon(%{action: "deactivated"}, _section), do: "hero-x-mark"
  defp diagnosis_event_timeline_icon(_, :recent), do: "hero-check-circle"
  defp diagnosis_event_timeline_icon(_, :old), do: "hero-document-text"

  defp diagnosis_event_label(%{action: "created", diagnosis_name: name}), do: "Dx creado: #{name}"

  defp diagnosis_event_label(%{action: "updated", diagnosis_name: name}),
    do: "Dx actualizado: #{name}"

  defp diagnosis_event_label(%{action: "deactivated", diagnosis_name: name}),
    do: "Dx desactivado: #{name}"

  defp diagnosis_event_label(_), do: "Dx"

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
