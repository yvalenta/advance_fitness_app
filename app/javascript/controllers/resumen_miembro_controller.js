import { Controller } from "@hotwired/stimulus"

// Popup de resumen rápido al hacer click/tab en un miembro (SDD Fase 5.13):
// muestra su membresía, permite editar el peso al vuelo, registrar su
// check-in y saltar directo a su ficha (membresía, antropometría, plan).
// Un solo <dialog> compartido, poblado desde los data-* de la fila que
// disparó la apertura.
export default class extends Controller {
  static targets = ["dialogo", "nombre", "estado", "pesoForm", "pesoInput", "checkinForm", "checkinInput", "perfilLink"]

  abrir(event) {
    const datos = event.params
    this.nombreTarget.textContent = datos.nombre
    this.estadoTarget.textContent = datos.estado
    this.pesoFormTarget.action = datos.medicionUrl
    this.pesoInputTarget.value = datos.pesoActual || ""
    this.checkinInputTarget.value = datos.id
    this.perfilLinkTarget.href = datos.perfilUrl
    this.dialogoTarget.showModal()
  }

  cerrar() {
    this.dialogoTarget.close()
  }

  // Cerrar al hacer click en el fondo (fuera de la caja). Cierre manual en
  // vez de un <form method="dialog"> (Fase 5.16): el submit del formulario
  // deja "filtrar" parte del click al elemento que queda debajo al cerrarse
  // — p. ej. el menú del navbar detrás del popup.
  cerrarEnBackdrop(event) {
    if (!event.target.closest(".modal-box")) this.dialogoTarget.close()
  }

  // Evita que el click en un control dentro de la fila (p. ej. "Registrar")
  // también dispare la apertura del popup.
  detener(event) {
    event.stopPropagation()
  }
}
