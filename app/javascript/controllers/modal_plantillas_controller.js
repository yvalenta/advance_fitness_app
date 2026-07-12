import { Controller } from "@hotwired/stimulus"

// Selector de plantillas de comida en un modal (<dialog> DaisyUI). "Aplicar
// plantilla" recuerda la card destino y abre el modal; al elegir una plantilla
// rellena los campos de esa card y dispara input para que autosave la guarde.
// "Guardar como plantilla" crea una plantilla nueva desde la card. Convive con
// "autosave" en el mismo elemento.
export default class extends Controller {
  static targets = ["dialogo", "grupo", "buscador", "chip", "vacio"]

  connect() {
    this.tipo = "todos"
  }

  abrir(event) {
    this.destino = event.target.closest("[data-autosave-target='card']")
    if (this.hasBuscadorTarget) { this.buscadorTarget.value = ""; this.tipo = "todos"; this.pintarChips(); this.filtrar() }
    this.dialogoTarget.showModal()
    this.buscadorTarget?.focus()
  }

  cerrar() {
    this.dialogoTarget.close()
  }

  // Cerrar al hacer click en el fondo. Cierre manual, no <form method="dialog">
  // (Fase 5.16): evita que el submit del backdrop deje pasar el click al
  // elemento que queda debajo al cerrarse.
  cerrarEnBackdrop(event) {
    if (!event.target.closest(".modal-box")) this.dialogoTarget.close()
  }

  // Búsqueda en vivo (texto + chip de tipo): oculta tarjetas que no coinciden
  // y las secciones que quedan vacías. Ignora mayúsculas y acentos.
  filtrar() {
    const consulta = this.normalizar(this.buscadorTarget.value)
    let visiblesTotal = 0

    this.grupoTargets.forEach((grupo) => {
      const seccion = grupo.closest("[data-seccion-tipo]") || grupo.parentElement
      if (this.tipo !== "todos" && grupo.dataset.tipo !== this.tipo) {
        seccion.hidden = true
        return
      }
      let visibles = 0
      grupo.querySelectorAll("button").forEach((boton) => {
        const coincide = this.normalizar(boton.textContent).includes(consulta)
        boton.hidden = !coincide
        if (coincide) visibles++
      })
      seccion.hidden = visibles === 0
      visiblesTotal += visibles
    })

    if (this.hasVacioTarget) this.vacioTarget.classList.toggle("hidden", visiblesTotal > 0)
  }

  filtrarTipo(event) {
    this.tipo = event.currentTarget.dataset.tipo
    this.pintarChips()
    this.filtrar()
  }

  pintarChips() {
    this.chipTargets.forEach((chip) => {
      const activo = chip.dataset.tipo === this.tipo
      chip.classList.toggle("btn-primary", activo)
      chip.classList.toggle("btn-ghost", !activo)
      chip.classList.toggle("border", !activo)
      chip.classList.toggle("border-base-300", !activo)
    })
  }

  normalizar(texto) {
    return (texto || "").toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "").trim()
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
    boton.className = "group flex flex-col gap-1 rounded-xl border border-base-300 px-3 py-2 text-left text-sm transition-colors hover:border-volt-d/50 hover:bg-volt/5"
    boton.dataset.action = "modal-plantillas#aplicar"
    boton.dataset.descripcion = plantilla.descripcion
    boton.dataset.kcal = plantilla.kcal
    boton.dataset.p = plantilla.proteinas_g
    boton.dataset.c = plantilla.carbohidratos_g
    boton.dataset.g = plantilla.grasas_g
    boton.innerHTML = `<span class="flex w-full items-center justify-between gap-2"><span class="min-w-0 flex-1 truncate font-medium">${plantilla.nombre}</span><span class="shrink-0 rounded-full bg-pulse/15 px-2 py-0.5 text-xs font-bold text-pulse">${plantilla.kcal} kcal</span></span><span class="text-xs text-steel-3">P ${plantilla.proteinas_g}g · C ${plantilla.carbohidratos_g}g · G ${plantilla.grasas_g}g</span>`
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
