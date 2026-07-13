import { Controller } from "@hotwired/stimulus"

// Flash de notice/alert (Fase 6.12): se cierra solo a los 5s o a mano. El
// contenedor es pointer-events-none (solo cada caja visible es "auto") para
// que su espacio vacío, aunque cubra la navbar (toast-top w-full), no
// bloquee los enlaces/menús de detrás mientras está en pantalla.
export default class extends Controller {
  static targets = ["item"]
  static values = { duracion: { type: Number, default: 5000 } }

  connect() {
    this.temporizador = setTimeout(() => this.cerrar(), this.duracionValue)
  }

  disconnect() {
    clearTimeout(this.temporizador)
  }

  cerrar() {
    clearTimeout(this.temporizador)
    this.itemTargets.forEach((item) => item.remove())
  }
}
