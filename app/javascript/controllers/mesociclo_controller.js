import { Controller } from "@hotwired/stimulus"

// Eje de semanas del mesociclo (Fase 14.9): pinta la barra de progreso de cada
// semana desde data-hechos/data-total y alterna qué semana está abierta. El
// contenido pesado (los paneles de día) vive en un turbo-frame perezoso por
// semana: solo la semana activa está en el DOM inicial; al seleccionar otra,
// su frame se destapa y Turbo lo carga (loading="lazy" + hidden). Los tabs de
// día viven DENTRO de cada frame — este controller nunca anida "tabs" en
// "tabs": los targets de Stimulus se resuelven por subárbol y el padre
// capturaría los del hijo.
export default class extends Controller {
  static targets = ["semana"]
  static values = { activa: Number }

  connect() {
    this.pintarBarras()
    this.resaltar(this.activaValue || 1)
  }

  pintarBarras() {
    this.semanaTargets.forEach((seccion) => {
      const total = Number(seccion.dataset.total)
      const hechos = Number(seccion.dataset.hechos)
      const barra = seccion.querySelector("[data-mesociclo-target='barra']")
      if (barra) barra.style.width = total > 0 ? `${Math.round((hechos / total) * 100)}%` : "0%"
    })
  }

  // Tap en la cabecera de una semana o en uno de sus chips de día.
  seleccionar(event) {
    const seccion = event.currentTarget.closest("[data-numero]")
    if (!seccion) return

    const numero = Number(seccion.dataset.numero)
    this.activaValue = numero
    this.resaltar(numero)

    const dia = event.currentTarget.dataset.diaIndice
    if (dia != null) this.abrirDia(seccion, Number(dia))
  }

  resaltar(numero) {
    this.semanaTargets.forEach((seccion) => {
      const activa = Number(seccion.dataset.numero) === numero
      seccion.classList.toggle("border-volt-d/60", activa)
      seccion.classList.toggle("border-base-300", !activa)

      // Semana activa: se destapa el frame (si aún no cargó, Turbo lo pide al
      // volverse visible) y se ocultan sus chips estáticos — los interactivos
      // llegan dentro del frame. Las demás vuelven al resumen con chips.
      const frame = seccion.querySelector("turbo-frame")
      if (frame) frame.hidden = !activa
      const chips = seccion.querySelector("[data-mesociclo-target='chips']")
      if (chips) chips.hidden = activa
    })
  }

  // Deep-link al día tocado: si el frame de la semana aún no cargó, espera su
  // turbo:frame-load y entonces abre ese tab.
  abrirDia(seccion, indice) {
    const frame = seccion.querySelector("turbo-frame")
    if (!frame) return

    const abrir = () => frame.querySelectorAll("[data-tabs-target='tab']")[indice]?.click()
    if (frame.querySelector("[data-tabs-target='tab']")) {
      abrir()
    } else {
      frame.addEventListener("turbo:frame-load", abrir, { once: true })
    }
  }
}
