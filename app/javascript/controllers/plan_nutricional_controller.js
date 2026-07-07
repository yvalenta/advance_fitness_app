import { Controller } from "@hotwired/stimulus"

// Checklist interactivo del plan nutricional: marcar comidas anima el
// total de kcal, la barra de progreso contra el objetivo y habilita
// registrar ese total como el consumo del día (upsert de la Fase 4).
export default class extends Controller {
  static targets = ["comida", "consumidas", "barra", "estado", "boton", "kcalInput", "segmento"]
  static values = { objetivo: Number }

  connect() {
    // Despliega la barra de macros (los anchos finales vienen en data-pct)
    requestAnimationFrame(() => {
      this.segmentoTargets.forEach((segmento) => (segmento.style.width = `${segmento.dataset.pct}%`))
    })
    this.actualizar()
  }

  actualizar() {
    const total = this.comidaTargets
      .filter((comida) => comida.checked)
      .reduce((suma, comida) => suma + Number(comida.dataset.kcal), 0)
    const completas = this.comidaTargets.length > 0 && this.comidaTargets.every((comida) => comida.checked)
    const progreso = this.objetivoValue > 0 ? Math.min((total / this.objetivoValue) * 100, 100) : 0

    this.animarNumero(this.consumidasTarget, total)
    if (this.hasBarraTarget) this.barraTarget.style.width = `${progreso}%`
    if (this.hasEstadoTarget) this.estadoTarget.hidden = !completas

    if (this.hasBotonTarget) {
      this.botonTarget.disabled = total === 0
      this.botonTarget.textContent =
        total === 0 ? "Marca lo que comiste hoy" : `Registrar ${total.toLocaleString("es-CO")} kcal como mi consumo de hoy`
    }
    if (this.hasKcalInputTarget) this.kcalInputTarget.value = total
  }

  // Count-up con easing cúbico — el número "corre" hasta el valor nuevo
  animarNumero(elemento, hasta) {
    const desde = Number(elemento.dataset.actual || 0)
    if (desde === hasta) return

    const inicio = performance.now()
    const duracion = 450
    const paso = (ahora) => {
      const avance = Math.min((ahora - inicio) / duracion, 1)
      const valor = Math.round(desde + (hasta - desde) * (1 - Math.pow(1 - avance, 3)))
      elemento.textContent = valor.toLocaleString("es-CO")
      if (avance < 1) requestAnimationFrame(paso)
    }
    requestAnimationFrame(paso)
    elemento.dataset.actual = hasta
  }
}
