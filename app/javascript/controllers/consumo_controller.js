import { Controller } from "@hotwired/stimulus"

// Hint vivo al registrar consumo (Fase 5.11): avisa mientras se escribe si el
// total supera el objetivo del día o queda por debajo (no alineado).
export default class extends Controller {
  static targets = ["campo", "hint"]
  static values = { objetivo: Number }

  actualizar() {
    const kcal = Number(this.campoTarget.value)
    const hint = this.hintTarget
    if (!kcal || this.objetivoValue <= 0) return (hint.hidden = true)

    const delta = kcal - this.objetivoValue
    hint.hidden = false
    if (delta > 0) {
      hint.className = "text-xs font-semibold text-error"
      hint.textContent = `Superarás tu objetivo por ${delta.toLocaleString("es-CO")} kcal — no alineado con tu meta.`
    } else if (delta < 0) {
      hint.className = "text-xs font-semibold text-warning"
      hint.textContent = `Quedarás ${Math.abs(delta).toLocaleString("es-CO")} kcal por debajo de tu objetivo.`
    } else {
      hint.className = "text-xs font-semibold text-success"
      hint.textContent = "Justo en tu objetivo."
    }
  }
}
