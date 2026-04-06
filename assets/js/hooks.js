(function () {
  const safeParseEvents = (rawValue) => {
    try {
      return JSON.parse(rawValue || "[]")
    } catch (_error) {
      return []
    }
  }

  window.CaeHooks = window.CaeHooks || {}

  window.CaeHooks.AvailabilityManager = {
    mounted() {
      this.calendar = null
      this.prevBtn = document.getElementById("calendar-nav-prev")
      this.nextBtn = document.getElementById("calendar-nav-next")
      this.titleEl = document.getElementById("calendar-title")
      this.viewSelect = document.getElementById("calendar-view-select")
      this.viewButtons = Array.from(document.querySelectorAll("[data-calendar-view]"))

      this.handleEvent("update_events", ({ events }) => {
        if (this.calendar) {
          this.calendar.removeAllEvents()
          this.calendar.addEventSource(events || [])
          this.calendar.render()
        }
      })

      if (!window.FullCalendar || !window.FullCalendar.Calendar) {
        this.el.innerHTML =
          '<div class="alert alert-error"><span>No se pudo cargar FullCalendar. Revisa scripts CDN/bloqueo del navegador.</span></div>'
        return
      }

      this.initCalendar()
    },

    initCalendar() {
      if (this.calendar) {
        this.calendar.destroy()
      }

      this.calendar = new window.FullCalendar.Calendar(this.el, {
        initialView: "dayGridMonth",
        locale: "es",
        selectable: true,
        editable: false,
        dragScroll: true,
        unselectAuto: false,
        selectMirror: true,
        nowIndicator: true,
        dayMaxEvents: 2,
        eventDisplay: "block",
        displayEventEnd: true,
        eventMinHeight: 34,
        eventShortHeight: 26,
        expandRows: true,
        slotEventOverlap: false,
        allDaySlot: true,
        allDayText: "Todo el dia",
        slotDuration: "00:30:00",
        slotLabelInterval: "01:00",
        slotMinTime: "07:00:00",
        slotMaxTime: "22:00:00",
        headerToolbar: false,
        views: {
          timeGridDay: {
            dayMaxEvents: false
          }
        },
        datesSet: (info) => {
          this.syncExternalHeader(info)
        },
        events: safeParseEvents(this.el.dataset.events),
        dateClick: (info) => {
          if (info.view.type === "dayGridMonth") {
            this.calendar.changeView("timeGridDay", info.date)
            this.calendar.unselect()
          }
        },
        select: (info) => {
          if (info.view.type === "dayGridMonth") {
            this.calendar.changeView("timeGridDay", info.start)
            this.calendar.unselect()
            return
          }

          if (info.view.type === "timeGridDay") {
            this.calendar.unselect()
            this.pushEvent("prepare_slot", {
              start: info.startStr,
              end: info.endStr
            })
          }
        },
        eventClick: (info) => {
          info.jsEvent.preventDefault()

          const status = info.event.extendedProps.status
          const eventId = info.event.id

          if (info.view.type === "timeGridDay" && status === "available" && eventId) {
            const ok = window.confirm("Deseas borrar esta disponibilidad?")
            if (ok) {
              this.pushEvent("delete_availability", { id: String(eventId) })
            }
            return
          }

          if (status === "booked" && eventId) {
            this.pushEvent("open_event_details", { id: String(eventId) })
            return
          }

          this.calendar.changeView("timeGridDay", info.event.start)
        },
        eventClassNames: (arg) => {
          const status = arg.event.extendedProps.status
          const releasedRecently = arg.event.extendedProps.released_recently

          if (status === "booked") return ["fc-event-primary"]
          if (status === "available" && releasedRecently) return ["fc-event-warning"]
          if (status === "available") return ["fc-event-success"]
          return []
        },
        eventContent: (arg) => {
          const status = arg.event.extendedProps.status
          const studentName = arg.event.extendedProps.student_name
          const releasedRecently = arg.event.extendedProps.released_recently

          if (status === "booked") {
            return {
              html: `
                <div class="flex flex-col gap-0.5 text-[11px] leading-tight">
                  <div class="truncate font-semibold">${studentName || "Turno ocupado"}</div>
                  <div class="truncate opacity-90">${arg.timeText || "Turno ocupado"}</div>
                </div>
              `
            }
          }

          if (status === "available" && releasedRecently) {
            return {
              html: `
                <div class="flex flex-col gap-0.5 text-[11px] leading-tight">
                  <div class="truncate font-semibold">Disponible (reabierto)</div>
                  <div class="truncate opacity-90">${arg.timeText || "Disponible"}</div>
                </div>
              `
            }
          }

          return { html: `<div class="text-xs font-medium">${arg.event.title}</div>` }
        },
        eventTimeFormat: {
          hour: "2-digit",
          minute: "2-digit",
          hour12: false
        }
      })

      this.calendar.render()
      this.bindExternalControls()
      this.syncExternalHeader({ view: this.calendar.view })
    },

    bindExternalControls() {
      if (this.prevBtn) {
        this.prevBtn.onclick = () => this.calendar.prev()
      }

      if (this.nextBtn) {
        this.nextBtn.onclick = () => this.calendar.next()
      }

      this.viewButtons.forEach((button) => {
        button.onclick = () => {
          const view = button.dataset.calendarView
          if (view) this.calendar.changeView(view)
        }
      })

      if (this.viewSelect) {
        this.viewSelect.onchange = (event) => {
          const view = event.target.value
          if (view) this.calendar.changeView(view)
        }
      }
    },

    syncExternalHeader(info) {
      const viewType = info?.view?.type || "dayGridMonth"
      const title = info?.view?.title || "Agenda"

      if (this.titleEl) {
        this.titleEl.textContent = title
      }

      this.viewButtons.forEach((button) => {
        const active = button.dataset.calendarView === viewType
        button.classList.toggle("btn-primary", active)
        button.classList.toggle("btn-soft", !active)
      })

      if (
        this.viewSelect &&
        ["dayGridMonth", "timeGridWeek", "timeGridDay", "listMonth"].includes(viewType)
      ) {
        this.viewSelect.value = viewType
      }
    },

    destroyed() {
      if (this.calendar) {
        this.calendar.destroy()
      }
    }
  }

  window.CaeHooks.BookingCalendarHook = {
    mounted() {
      this.calendar = null

      this.handleEvent("refresh_events", ({ events }) => {
        if (this.calendar) {
          this.calendar.removeAllEvents()
          this.calendar.addEventSource(events || [])
          this.calendar.render()
        }
      })

      if (!window.FullCalendar || !window.FullCalendar.Calendar) {
        this.el.innerHTML =
          '<div class="alert alert-error"><span>No se pudo cargar FullCalendar. Revisa scripts CDN/bloqueo del navegador.</span></div>'
        return
      }

      this.initCalendar()
    },

    initCalendar() {
      if (this.calendar) {
        this.calendar.destroy()
      }

      this.calendar = new window.FullCalendar.Calendar(this.el, {
        initialView: "dayGridMonth",
        locale: "es",
        selectable: false,
        editable: false,
        dragScroll: true,
        nowIndicator: true,
        dayMaxEvents: 2,
        eventDisplay: "block",
        displayEventEnd: true,
        eventMinHeight: 34,
        eventShortHeight: 26,
        expandRows: true,
        slotEventOverlap: false,
        allDaySlot: true,
        allDayText: "Todo el dia",
        slotDuration: "00:30:00",
        slotLabelInterval: "01:00",
        slotMinTime: "07:00:00",
        slotMaxTime: "22:00:00",
        headerToolbar: {
          left: "prev,next today",
          center: "title",
          right: "dayGridMonth,timeGridWeek,timeGridDay,listMonth"
        },
        buttonText: {
          today: "Hoy",
          month: "Mes",
          week: "Semana",
          day: "Dia",
          list: "Lista"
        },
        events: safeParseEvents(this.el.dataset.events),
        eventClick: (info) => {
          info.jsEvent.preventDefault()

          this.pushEvent("select_appointment_slot", {
            id: String(info.event.id),
            start: info.event.startStr,
            end: info.event.endStr
          })
        },
        eventClassNames: (arg) => {
          const status = arg.event.extendedProps.status
          if (status === "available") return ["fc-event-success"]
          return ["fc-event-info"]
        },
        eventContent: (arg) => {
          const professionalName = arg.event.extendedProps.professional_name

          return {
            html: `
              <div class="flex flex-col gap-0.5 text-[11px] leading-tight">
                <div class="truncate font-semibold">${professionalName || "Disponible"}</div>
                <div class="truncate opacity-90">${arg.timeText || "Turno"}</div>
              </div>
            `
          }
        },
        eventTimeFormat: {
          hour: "2-digit",
          minute: "2-digit",
          hour12: false
        }
      })

      this.calendar.render()
    },

    destroyed() {
      if (this.calendar) {
        this.calendar.destroy()
      }
    }
  }

})()
