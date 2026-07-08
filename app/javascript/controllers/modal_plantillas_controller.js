import { Controller } from "@hotwired/stimulus"

// Selector de plantillas de comida en un modal (<dialog> DaisyUI). "Aplicar
// plantilla" recuerda la card destino y abre el modal; al elegir una plantilla
// rellena los campos de esa card y dispara input para que autosave la guarde.
// "Guardar como plantilla" crea una plantilla nueva desde la card. Convive con
// "autosave" en el mismo elemento.
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
    const opcion = event.currentTarget.dataset
    if (!this.destino) return

    this.fijar("descripcion", opcion.descripcion)
    this.fijar("kcal", opcion.kcal)
    this.fijar("proteinas_g", opcion.p)
    this.fijar("carbohidratos_g", opcion.c)
    this.fijar("grasas_g", opcion.g)
    this.dialogoTarget.close()
    this.destino.querySelector("[name$='[kcal]']")
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
        plantilla_comida: {
          tipo: boton.dataset.tipo,
          nombre: `${valor("nombre")} · ${valor("kcal")} kcal`,
          descripcion: valor("descripcion"), kcal: valor("kcal"),
          proteinas_g: valor("proteinas_g"), carbohidratos_g: valor("carbohidratos_g"), grasas_g: valor("grasas_g")
        }
      })
    })

    if (respuesta.ok) {
      this.agregarAlModal(await respuesta.json())
      this.confirmar(boton, "✓ Guardada")
    } else {
      const datos = await respuesta.json().catch(() => ({}))
      this.confirmar(boton, datos.errores?.[0] || "No se pudo guardar")
    }
  }

  agregarAlModal(plantilla) {
    const grupo = this.grupoTargets.find((g) => g.dataset.tipo === plantilla.tipo)
    if (!grupo) return
    const boton = document.createElement("button")
    boton.type = "button"
    boton.className = "btn btn-ghost btn-sm w-full justify-between font-normal"
    boton.dataset.action = "modal-plantillas#aplicar"
    boton.dataset.descripcion = plantilla.descripcion
    boton.dataset.kcal = plantilla.kcal
    boton.dataset.p = plantilla.proteinas_g
    boton.dataset.c = plantilla.carbohidratos_g
    boton.dataset.g = plantilla.grasas_g
    boton.innerHTML = `<span>${plantilla.nombre}</span><span class="text-xs text-steel-3">${plantilla.kcal} kcal</span>`
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
