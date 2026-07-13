import { Controller } from "@hotwired/stimulus"

// Buscador en vivo (Fase 6.13): reenvía el form de búsqueda (GET) al
// escribir, con debounce. El form vive dentro de un turbo-frame, así que
// Turbo navega SOLO ese frame — la tabla se filtra sin recargar la página.
export default class extends Controller {
  static targets = ["form"]
  static values = { espera: { type: Number, default: 300 } }

  buscar() {
    clearTimeout(this.temporizador)
    this.temporizador = setTimeout(() => this.formTarget.requestSubmit(), this.esperaValue)
  }
}
