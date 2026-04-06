(function () {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  const hooks = window.CaeHooks || {}
  const LiveSocketCtor =
    window.LiveSocket ||
    window.LiveView?.LiveSocket ||
    window.Phoenix?.LiveView?.LiveSocket ||
    window.Phoenix?.LiveSocket
  const PhoenixSocketCtor = window.Phoenix?.Socket || window.Socket

  if (LiveSocketCtor && PhoenixSocketCtor) {
    const liveSocket = new LiveSocketCtor("/live", PhoenixSocketCtor, {
      params: { _csrf_token: csrfToken },
      hooks: hooks
    })

    liveSocket.connect()
    window.liveSocket = liveSocket
  }

  document.querySelectorAll("[role=alert][data-flash]").forEach((el) => {
    el.addEventListener("click", () => {
      el.setAttribute("hidden", "")
    })
  })
})()
