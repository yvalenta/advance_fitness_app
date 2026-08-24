import { Controller } from "@hotwired/stimulus"

// Calculadora de 1RM estimado (fórmula de Epley) para series hipotéticas —
// mismo límite de 12 reps que CalculadoraUnaRepMax (app/services), aquí solo
// para la vista previa instantánea: es aritmética, no pide nada al servidor.
export default class extends Controller {
  static targets = ["peso", "repeticiones", "resultado"]

  calcular() {
    const peso = parseFloat(this.pesoTarget.value)
    const repeticiones = parseInt(this.repeticionesTarget.value, 10)

    if (!peso || !repeticiones || repeticiones < 1 || repeticiones > 12) {
      this.resultadoTarget.textContent = "—"
      return
    }

    const estimado = peso * (1 + repeticiones / 30)
    this.resultadoTarget.textContent = `${estimado.toFixed(1)} kg`
  }
}
