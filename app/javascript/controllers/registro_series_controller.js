import { Controller } from "@hotwired/stimulus"

// Popup de registro de series reales (Fase 11-A, SDD §18, feature premium):
// clon de ayuda_ejercicio_controller — tap en "Registrar" → el turbo-frame
// del dialog carga el formulario de series bajo demanda.
export default class extends Controller {
  static targets = ["dialogo", "marco"]

  abrir(event) {
    const url = event.currentTarget.dataset.registroSeriesUrl
    if (!url) return

    this.marcoTarget.src = url
    this.dialogoTarget.showModal()
  }

  cerrar() {
    this.dialogoTarget.close()
    this.marcoTarget.removeAttribute("src")
    this.marcoTarget.innerHTML = '<div class="flex justify-center py-10"><span class="loading loading-spinner loading-md"></span></div>'
  }

  cerrarEnBackdrop(event) {
    if (!event.target.closest(".modal-box")) this.cerrar()
  }
}
