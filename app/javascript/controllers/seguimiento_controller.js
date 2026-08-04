import { Controller } from "@hotwired/stimulus"

// Seguimiento de entrenamiento inline (Fase 5.11): un check por ejercicio en
// las tabs de la rutina semanal (la fecha viene del panel del día — semana
// actual) y una "novedad" para toda la rutina del día. Guarda sin recargar y
// no muta el plan del coach.
export default class extends Controller {
  static targets = ["estado"]
  static values = { url: String }

  marcar(event) {
    const fila = event.target.closest("[data-indice]")
    // Fase 14.6: el ancla real es el uid estable del contenedor del ejercicio;
    // indice/nombre siguen viajando como metadato histórico. Si el atributo
    // aún no está en el DOM (plan viejo sin uid), va vacío y el servidor cae
    // al anclaje posicional.
    const uid = fila.dataset.uid || event.target.closest("[data-uid]")?.dataset.uid || ""
    this.enviar(event.target, {
      uid,
      indice: fila.dataset.indice,
      nombre: fila.dataset.nombre,
      hecho: event.target.checked
    })
  }

  novedad(event) {
    this.enviar(event.target, { novedad: event.target.value })
  }

  async enviar(origen, cuerpo) {
    const fecha = origen.closest("[data-fecha]")?.dataset.fecha
    if (!fecha) return
    this.avisar("Guardando…")

    const respuesta = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ fecha, ...cuerpo })
    })

    this.avisar(respuesta.ok ? "Guardado ✓" : "Error al guardar")
  }

  avisar(texto) {
    if (this.hasEstadoTarget) this.estadoTarget.textContent = texto
  }
}
