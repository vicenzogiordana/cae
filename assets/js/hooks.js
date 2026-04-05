(function () {
  const ClinicScheduleCalendar = {
    mounted() {
      this.calendar = null;
      this.initCalendar(this.readEvents());

      this.handleEvent("schedule:events", ({ events }) => {
        if (this.calendar) {
          this.calendar.removeAllEvents();
          this.calendar.addEventSource(events || []);
        } else {
          this.initCalendar(events || []);
        }
      });
    },

    destroyed() {
      if (this.calendar) {
        this.calendar.destroy();
        this.calendar = null;
      }
    },

    readEvents() {
      try {
        return JSON.parse(this.el.dataset.events || "[]");
      } catch (_error) {
        return [];
      }
    },

    initCalendar(events) {
      if (!window.FullCalendar || this.calendar) {
        return;
      }

      this.calendar = new window.FullCalendar.Calendar(this.el, {
        initialView: "dayGridMonth",
        locale: "es",
        buttonText: {
          today: "Hoy",
          month: "Mes",
          week: "Semana",
          day: "Dia",
          list: "Lista"
        },
        headerToolbar: {
          left: "prev,next today",
          center: "title",
          right: "dayGridMonth,timeGridWeek,timeGridDay"
        },
        events: events || []
      });

      this.calendar.render();
    }
  };

  window.CaeHooks = {
    ClinicScheduleCalendar
  };
})();
