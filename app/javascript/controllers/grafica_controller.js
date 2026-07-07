import { Controller } from "@hotwired/stimulus"

// Tooltip flotante para las gráficas SVG: cualquier elemento con
// data-etiqueta dentro del contenedor lo muestra al pasar el mouse.
export default class extends Controller {
  static targets = ["tooltip"]

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
}
