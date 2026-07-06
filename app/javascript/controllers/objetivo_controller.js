import { Controller } from "@hotwired/stimulus"

// Vista previa en vivo del objetivo calórico (Mifflin-St Jeor).
// Espeja los services del servidor (CalculadoraTdee / ObjetivoCalorico);
// el cálculo definitivo siempre se hace y persiste server-side.
export default class extends Controller {
  static targets = ["peso", "tipo", "tdee", "objetivo", "detalle"]
  static values = { talla: Number, edad: Number, sexo: String, factor: Number, superavit: Number }

  connect() {
    this.calcular()
  }

  calcular() {
    const peso = parseFloat(this.pesoTarget.value.replace(",", "."))
    const tipo = this.tipoTargets.find((radio) => radio.checked)?.value

    if (!peso || peso <= 0 || !tipo) {
      this.tdeeTarget.textContent = "—"
      this.objetivoTarget.textContent = "—"
      this.detalleTarget.textContent = "Elige tu meta e ingresa tu peso"
      return
    }

    const base = 10 * peso + 6.25 * this.tallaValue - 5 * this.edadValue
    const tmb = this.sexoValue === "F" ? base - 161 : base + 5
    const tdee = Math.round(tmb * this.factorValue)
    const ajuste = { deficit: -500, mantenimiento: 0, superavit: this.superavitValue }[tipo]

    const formato = new Intl.NumberFormat("es-CO")
    this.tdeeTarget.textContent = `${formato.format(tdee)} kcal`
    this.objetivoTarget.textContent = formato.format(tdee + ajuste)
    this.detalleTarget.textContent =
      ajuste === 0
        ? "igual a tu TDEE (mantenimiento)"
        : ajuste < 0
          ? `TDEE − ${Math.abs(ajuste)} kcal de déficit`
          : `TDEE + ${ajuste} kcal de superávit`
  }
}
