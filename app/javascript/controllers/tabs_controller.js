import { Controller } from "@hotwired/stimulus"

// Tabs server-rendered (rutina por día, SDD §14): solo alterna clases y
// visibilidad, el contenido ya viene en el HTML.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.mostrar(0)
  }

  seleccionar(event) {
    this.mostrar(this.tabTargets.indexOf(event.currentTarget))
  }

  mostrar(indice) {
    this.tabTargets.forEach((tab, i) => tab.classList.toggle("tab-active", i === indice))
    this.panelTargets.forEach((panel, i) => (panel.hidden = i !== indice))
  }
}
