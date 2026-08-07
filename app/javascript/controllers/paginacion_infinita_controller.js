import { Controller } from "@hotwired/stimulus"

// Paginación por scroll (Fase 18p, petición del cliente: "en móvil no
// necesitamos botones, necesitamos lazy loading"). El centinela del partial
// shared/_paginacion observa su entrada al viewport: pide la página
// siguiente (HTML normal, mismo endpoint con ?page=), appendea sus filas al
// tbody del frame y se REEMPLAZA por el centinela de esa página — que ya
// apunta a la siguiente, o por el "fin de la lista" en la última. Una
// búsqueda nueva recarga el frame entero y el ciclo renace en su página 1.
export default class extends Controller {
  static values = { url: String, marco: String }

  connect() {
    // rootMargin adelanta la carga ~una pantalla antes de llegar al fondo:
    // el que scrollea no ve el "cargando" si la red acompaña.
    this.observador = new IntersectionObserver((entradas) => {
      if (entradas.some((entrada) => entrada.isIntersecting)) this.cargar()
    }, { rootMargin: "300px" })
    this.observador.observe(this.element)
  }

  disconnect() { this.observador?.disconnect() }

  async cargar() {
    if (this.cargando || !this.urlValue) return
    this.cargando = true

    try {
      const respuesta = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      if (!respuesta.ok) throw new Error(`HTTP ${respuesta.status}`)

      const doc = new DOMParser().parseFromString(await respuesta.text(), "text/html")
      const marcoNuevo = doc.getElementById(this.marcoValue)
      const tbody = document.getElementById(this.marcoValue)?.querySelector("tbody")
      if (!marcoNuevo || !tbody) { this.element.remove(); return }

      marcoNuevo.querySelectorAll("tbody tr").forEach((fila) => tbody.appendChild(fila))

      // El relevo: el centinela de la página cargada (o su "fin de la lista")
      // toma el lugar de este. Adoptar el nodo del doc parseado es válido y
      // Stimulus se conecta solo al verlo entrar al DOM.
      const relevo = marcoNuevo.querySelector("[data-controller='paginacion-infinita'], [data-fin-lista]")
      if (relevo) this.element.replaceWith(relevo)
      else this.element.remove()
    } catch {
      // Sin red no se rompe la lista: el centinela queda y el próximo scroll
      // (o volver a entrar al viewport) reintenta.
      this.cargando = false
    }
  }
}
