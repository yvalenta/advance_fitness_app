import { Controller } from "@hotwired/stimulus"

// Captura rápida de series (Fase 12): por defecto se asume "cumplido tal
// cual" (el target del plan); al desmarcar el checkbox aparecen los campos
// manuales de reps/peso/RPE para registrar la variación. Puro cliente, sin
// round-trip al servidor — solo togglea visibilidad.
export default class extends Controller {
  static targets = ["checkbox", "camposManual", "botonCumplido"]

  connect() {
    this.alternar()
  }

  alternar() {
    const cumplido = this.hasCheckboxTarget ? this.checkboxTarget.checked : false
    if (this.hasCamposManualTarget) this.camposManualTarget.classList.toggle("hidden", cumplido)
    if (this.hasBotonCumplidoTarget) this.botonCumplidoTarget.classList.toggle("hidden", !cumplido)
  }
}
