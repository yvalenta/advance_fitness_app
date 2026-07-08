import { Controller } from "@hotwired/stimulus"

// Selector de plantillas de EJERCICIO en un modal (<dialog> DaisyUI), agrupadas
// por músculo. Espeja modal_plantillas pero con los campos de ejercicio.
// Convive con "autosave" en el mismo elemento.
export default class extends Controller {
  static targets = ["dialogo", "grupo"]

  abrir(event) {
    this.destino = event.target.closest("[data-autosave-target='card']")
    this.dialogoTarget.showModal()
  }

  cerrar() {
    this.dialogoTarget.close()
  }

  aplicar(event) {
    const o = event.currentTarget.dataset
    if (!this.destino) return

    this.fijar("nombre", o.nombre)
    this.fijar("series", o.series)
    this.fijar("repeticiones", o.repeticiones)
    this.fijar("descanso_seg", o.descanso)
    this.dialogoTarget.close()
    this.destino.querySelector("[name$='[nombre]']")
      ?.dispatchEvent(new Event("input", { bubbles: true }))
  }

  async guardarPlantilla(event) {
    const boton = event.currentTarget
    const card = boton.closest("[data-autosave-target='card']")
    const valor = (nombre) => card.querySelector(`[name$="[${nombre}]"]`)?.value

    const respuesta = await fetch(this.data.get("crearUrl"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({
        plantilla_ejercicio: {
          musculo: boton.dataset.musculo || "otro",
          nombre: valor("nombre"), series: valor("series"),
          repeticiones: valor("repeticiones"), descanso_seg: valor("descanso_seg")
        }
      })
    })

    if (respuesta.ok) {
      this.agregarAlModal(await respuesta.json())
      this.confirmar(boton, "✓ Guardado")
    } else {
      const datos = await respuesta.json().catch(() => ({}))
      this.confirmar(boton, datos.errores?.[0] || "No se pudo guardar")
    }
  }

  agregarAlModal(plantilla) {
    const grupo = this.grupoTargets.find((g) => g.dataset.musculo === plantilla.musculo)
    if (!grupo) return
    const boton = document.createElement("button")
    boton.type = "button"
    boton.className = "btn btn-ghost btn-sm w-full justify-between font-normal"
    boton.dataset.action = "modal-ejercicios#aplicar"
    boton.dataset.nombre = plantilla.nombre
    boton.dataset.series = plantilla.series
    boton.dataset.repeticiones = plantilla.repeticiones
    boton.dataset.descanso = plantilla.descanso_seg
    boton.innerHTML = `<span>${plantilla.nombre}</span><span class="text-xs text-steel-3">${plantilla.series}×${plantilla.repeticiones}</span>`
    grupo.appendChild(boton)
  }

  confirmar(boton, texto) {
    const original = boton.textContent
    boton.textContent = texto
    boton.disabled = true
    setTimeout(() => { boton.textContent = original; boton.disabled = false }, 2200)
  }

  fijar(nombre, valor) {
    const campo = this.destino.querySelector(`[name$="[${nombre}]"]`)
    if (campo && valor != null) campo.value = valor
  }
}
