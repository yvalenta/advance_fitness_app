import { Controller } from "@hotwired/stimulus"

// Buscador en vivo (Fase 6.13): reenvía el form de búsqueda (GET) al
// escribir, con debounce. Fase 18p: el form vive FUERA del turbo-frame de
// resultados — adentro, cada recarga del frame se llevaba el input con el
// foco y las letras a medio teclear (bug reportado). Turbo navega solo el
// frame vía data-turbo-frame y el campo no se toca.
export default class extends Controller {
  static targets = ["form", "entrada"]
  static values = { espera: { type: Number, default: 300 } }

  buscar() {
    clearTimeout(this.temporizador)
    this.temporizador = setTimeout(() => this.formTarget.requestSubmit(), this.esperaValue)
  }

  // "Limpiar" navega el frame a la lista completa; el input, que ya no viaja
  // en el frame, se vacía aquí para que cuente la misma historia.
  limpiar() {
    if (this.hasEntradaTarget) this.entradaTarget.value = ""
  }
}
