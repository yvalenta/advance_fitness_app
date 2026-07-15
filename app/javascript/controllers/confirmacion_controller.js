import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Confirmación global vía <dialog>, en vez de window.confirm (Fase 6.9):
// en iOS con la app agregada a inicio ("apple-mobile-web-app-capable"),
// window.confirm/alert no hacen nada — el navegador standalone los ignora
// silenciosamente, dejando acciones destructivas (eliminar ejercicio/comida,
// publicar plan, cancelar suscripción) sin efecto y sin aviso. Este
// controller sustituye el método de confirmación de Turbo (data-turbo-
// confirm) y queda disponible para cualquier fetch manual del mismo modo.
export default class extends Controller {
  static targets = ["mensaje", "aceptar"]

  connect() {
    Turbo.config.forms.confirm = (mensaje) => this.preguntar(mensaje)
    window.confirmarAccion = (mensaje) => this.preguntar(mensaje)
  }

  // Reentrancia (doble tap en el botón, típico en el ícono pequeño de
  // "eliminar" en móvil): si el diálogo ya estaba abierto de un llamado
  // anterior, showModal() sobre un <dialog> ya abierto lanza una excepción
  // no capturada dentro de la promesa — el resolver nunca se llama y el
  // botón que esperaba la respuesta queda colgado hasta recargar la página.
  // Se resuelve primero el pendiente como cancelado antes de abrir el nuevo.
  preguntar(mensaje) {
    if (this.element.open) this.cerrar(false)
    this.mensajeTarget.textContent = mensaje
    this.element.showModal()
    return new Promise((resolver) => { this.resolver = resolver })
  }

  aceptar() {
    this.cerrar(true)
  }

  cancelar() {
    this.cerrar(false)
  }

  cerrarEnBackdrop(event) {
    if (!event.target.closest(".modal-box")) this.cerrar(false)
  }

  cerrar(resultado) {
    this.element.close()
    this.resolver?.(resultado)
    this.resolver = null
  }
}
