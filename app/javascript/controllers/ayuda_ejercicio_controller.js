import { Controller } from "@hotwired/stimulus"

// Popup de ayuda de ejecución de un ejercicio (Fase 6.3): tap en el nombre →
// el turbo-frame del dialog carga el GIF + instrucciones bajo demanda, sin
// recargar la página ni tocar los checks (que ya persisten al instante).
export default class extends Controller {
  static targets = ["dialogo", "marco"]

  abrir(event) {
    const url = event.currentTarget.dataset.ayudaUrl
    if (!url) return

    this.marcoTarget.src = url
    this.dialogoTarget.showModal()
  }

  // Al cerrar se vacía el frame: corta la descarga/animación del GIF y deja
  // el spinner listo para la próxima apertura.
  cerrar() {
    this.dialogoTarget.close()
    this.marcoTarget.removeAttribute("src")
    this.marcoTarget.innerHTML = '<div class="flex justify-center py-10"><span class="loading loading-spinner loading-md"></span></div>'
  }

  // Cierre por click en el fondo (patrón Fase 5.16: manual, sin form dialog)
  cerrarEnBackdrop(event) {
    if (!event.target.closest(".modal-box")) this.cerrar()
  }
}
