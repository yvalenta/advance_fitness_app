import { Controller } from "@hotwired/stimulus"

// Alterna la tarjeta de rutina entre "ver" (checks + cápsulas) y "editar"
// (inputs inline), sin duplicar el componente (Fase 6.8). El staff entra
// siempre en modo edición (editando: true de entrada) y no ve el botón.
export default class extends Controller {
  static targets = ["lectura", "edicion", "boton"]
  static values = { editando: Boolean }

  editandoValueChanged() {
    this.lecturaTargets.forEach((el) => (el.hidden = this.editandoValue))
    this.edicionTargets.forEach((el) => (el.hidden = !this.editandoValue))
    this.botonTargets.forEach((b) => (b.textContent = this.editandoValue ? "Listo" : "Editar"))
  }

  alternar() {
    this.editandoValue = !this.editandoValue
  }
}
