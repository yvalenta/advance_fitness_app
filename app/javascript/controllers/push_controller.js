import { Controller } from "@hotwired/stimulus"

// Opt-in de Web Push (Fase 15): pide el permiso desde el gesto del usuario
// (requisito de los navegadores), suscribe ESTE dispositivo con la llave
// VAPID pública y registra el endpoint en el servidor. En iOS (16.4+) el
// push solo existe con la PWA instalada en inicio: sin standalone se
// muestra la pista de instalación en vez de un botón que fallaría.
export default class extends Controller {
  static targets = ["zona", "pista", "apagado", "encendido"]
  static values = { clave: String, url: String }

  async connect() {
    if (!this.soportado()) {
      if (this.esIosSinInstalar()) {
        this.zonaTarget.classList.remove("hidden")
        this.pistaTarget.classList.remove("hidden")
      }
      return
    }
    const registro = await navigator.serviceWorker.ready
    const suscripcion = await registro.pushManager.getSubscription()
    this.pintar(Notification.permission === "granted" && !!suscripcion)
  }

  async activar() {
    if (Notification.permission === "denied") return
    if ((await Notification.requestPermission()) !== "granted") return

    const registro = await navigator.serviceWorker.ready
    const suscripcion = await registro.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.claveDecodificada()
    })
    const { endpoint, keys } = suscripcion.toJSON()
    const respuesta = await fetch(this.urlValue, {
      method: "POST",
      headers: this.cabeceras(),
      body: JSON.stringify({ endpoint: endpoint, p256dh: keys.p256dh, auth: keys.auth })
    })
    if (respuesta.ok) this.pintar(true)
  }

  async desactivar() {
    const registro = await navigator.serviceWorker.ready
    const suscripcion = await registro.pushManager.getSubscription()
    if (suscripcion) {
      await fetch(this.urlValue, {
        method: "DELETE",
        headers: this.cabeceras(),
        body: JSON.stringify({ endpoint: suscripcion.endpoint })
      })
      await suscripcion.unsubscribe()
    }
    this.pintar(false)
  }

  // ── privados ──────────────────────────────────────────────────────────

  soportado() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  esIosSinInstalar() {
    const ios = /iphone|ipad|ipod/i.test(navigator.userAgent)
    const instalada = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
    return ios && !instalada
  }

  pintar(activa) {
    this.zonaTarget.classList.remove("hidden")
    this.pistaTarget.classList.add("hidden")
    this.apagadoTarget.classList.toggle("hidden", activa)
    this.encendidoTarget.classList.toggle("hidden", !activa)
  }

  // La llave VAPID viaja como base64 URL-safe; PushManager espera bytes.
  claveDecodificada() {
    const base64 = this.claveValue.replace(/-/g, "+").replace(/_/g, "/")
    const relleno = "=".repeat((4 - (base64.length % 4)) % 4)
    return Uint8Array.from(atob(base64 + relleno), (c) => c.charCodeAt(0))
  }

  cabeceras() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
    }
  }
}
