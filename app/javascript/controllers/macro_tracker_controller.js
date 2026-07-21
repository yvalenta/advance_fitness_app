import { Controller } from "@hotwired/stimulus"

// Suma macros y kcal en vivo mientras el usuario edita las comidas.
// Lee los inputs [name="comida[X]"] de cada card y actualiza los totales
// y la barra de progreso de proteínas contra la meta recomendada.
export default class extends Controller {
  static targets = ["proteinas", "carbos", "grasas", "kcal", "barraProteina", "textoProteina"]
  static values = { metaProteina: Number }

  connect() {
    this.recalcular()
  }

  recalcular() {
    const cards = this.element.querySelectorAll("[data-autosave-target='card']")
    let p = 0, c = 0, g = 0, kcal = 0

    cards.forEach((card) => {
      p    += parseFloat(card.querySelector("[name='comida[proteinas_g]']")?.value  || 0)
      c    += parseFloat(card.querySelector("[name='comida[carbohidratos_g]']")?.value || 0)
      g    += parseFloat(card.querySelector("[name='comida[grasas_g]']")?.value    || 0)
      kcal += parseFloat(card.querySelector("[name='comida[kcal]']")?.value        || 0)
    })

    if (this.hasProteinasTarget) this.proteinasTarget.textContent = Math.round(p)
    if (this.hasCarbosTarget)    this.carbosTarget.textContent    = Math.round(c)
    if (this.hasGrasasTarget)    this.grasasTarget.textContent    = Math.round(g)
    if (this.hasKcalTarget)      this.kcalTarget.textContent      = Math.round(kcal).toLocaleString("es-CO")

    if (this.metaProteinaValue > 0 && this.hasBarraProteinaTarget) {
      const pct = Math.min((p / this.metaProteinaValue) * 100, 100)
      this.barraProteinaTarget.style.width = `${pct}%`
      if (this.hasTextoProteinaTarget) {
        const falta = Math.max(this.metaProteinaValue - p, 0)
        this.textoProteinaTarget.textContent =
          falta > 0 ? `Faltan ${Math.round(falta)}g para tu meta` : "¡Meta de proteínas alcanzada! 💪"
      }
    }
  }
}
