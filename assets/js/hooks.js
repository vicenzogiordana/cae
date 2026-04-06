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
        unselectAuto: false,
        selectMirror: true,
        nowIndicator: true,
        dayMaxEvents: true,
        eventDisplay: "block",
        slotMinTime: "07:00:00",
        slotMaxTime: "22:00:00",
        headerToolbar: {
          left: "prev,next today",
          center: "title",
          right: "dayGridMonth,timeGridDay"
        },
        buttonText: {
          today: "Hoy",
          month: "Mes",
          day: "Dia"
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
          this.calendar.changeView("timeGridDay", info.event.start)
        },
        eventClassNames: (arg) => {
          const status = arg.event.extendedProps.status
          if (status === "booked") return ["fc-event-primary"]
          if (status === "available") return ["fc-event-success"]
          if (status === "blocked") return ["fc-event-warning"]
          return []
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
