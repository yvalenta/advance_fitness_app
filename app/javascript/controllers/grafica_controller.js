import { Controller } from "@hotwired/stimulus"

// Interactividad de las gráficas SVG:
// - tooltip flotante sobre elementos con data-etiqueta
// - click/tap en un punto o barra (data-indice) abre su panel de detalle
//   con la referencia de la métrica; repetir el click lo cierra
export default class extends Controller {
  static targets = ["tooltip", "detalle"]

  mostrar(event) {
    const punto = event.target.closest("[data-etiqueta]")
    if (!punto) return this.ocultar()

    const marco = this.element.getBoundingClientRect()
    this.tooltipTarget.textContent = punto.dataset.etiqueta
    this.tooltipTarget.hidden = false
    this.tooltipTarget.style.left = `${Math.min(Math.max(event.clientX - marco.left, 40), marco.width - 40)}px`
    this.tooltipTarget.style.top = `${event.clientY - marco.top - 36}px`
  }

  ocultar() {
    this.tooltipTarget.hidden = true
  }

  seleccionar(event) {
    const elemento = event.target.closest("[data-indice]")
    if (!elemento) return

    const indice = elemento.dataset.indice
    const cerrar = this.seleccionado === indice
    this.seleccionado = cerrar ? null : indice

    this.element.querySelectorAll(".grafica-seleccionada")
      .forEach((marcado) => marcado.classList.remove("grafica-seleccionada"))
    if (!cerrar) elemento.classList.add("grafica-seleccionada")

    this.detalleTargets.forEach((detalle) => {
      detalle.hidden = cerrar || detalle.dataset.indice !== indice
    })
  }
}
