import { Controller } from "@hotwired/stimulus"

// Pantalla activa durante el modo sesión (Fase 19d): pide el Wake Lock al
// conectar y lo libera al desconectar (salir de /sesion) — el navegador ya
// lo libera solo al perder visibilidad, así que lo reintentamos al volver
// (cambiar de app y volver no debería dejar la pantalla sin bloquear).
// Apagable en Ajustes (data-wake-lock-activo-value): si el miembro lo
// desactivó, o el navegador no soporta la API, no hace nada — mismo patrón
// de feature-detection que push_controller.js.
export default class extends Controller {
  static values = { activo: Boolean }

  connect() {
    this.candado = null
    if (!this.activoValue || !("wakeLock" in navigator)) return

    this.reanudar = this.reanudar.bind(this)
    document.addEventListener("visibilitychange", this.reanudar)
    this.pedir()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.reanudar)
    this.liberar()
  }

  pedir() {
    navigator.wakeLock.request("screen")
      .then((candado) => { this.candado = candado })
      .catch(() => {}) // batería baja, permiso denegado, etc. — entrenar sigue funcionando igual
  }

  liberar() {
    if (this.candado) this.candado.release().catch(() => {})
    this.candado = null
  }

  reanudar() {
    if (document.visibilityState === "visible" && !this.candado) this.pedir()
  }
}
