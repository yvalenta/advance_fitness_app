import { Controller } from "@hotwired/stimulus"

// Seguimiento de entrenamiento (Fase 5.10): marca Hecho/Pendiente + nota por
// ejercicio del día y lo guarda sin recargar. El selector de fecha recarga solo
// esta tarjeta (turbo-frame). No muta el plan del coach.
export default class extends Controller {
  static values = { url: String, fecha: String }

  // Cambiar la fecha recarga el turbo-frame con la rutina de ese día.
  cambiarFecha(event) {
    event.target.form.requestSubmit()
  }

  async marcar(event) {
    const fila = event.target.closest("[data-indice]")
    const check = fila.querySelector("input[type=checkbox]")
    const nota = fila.querySelector("input[type=text]")
    const estado = fila.querySelector("[data-seguimiento-target=estado]")
    if (estado) estado.textContent = "Guardando…"

    const respuesta = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({
        fecha: this.fechaValue,
        indice: fila.dataset.indice,
        nombre: fila.dataset.nombre,
        hecho: check.checked,
        nota: nota?.value || ""
      })
    })

    if (estado) estado.textContent = respuesta.ok ? "Guardado ✓" : "Error al guardar"
  }
}
