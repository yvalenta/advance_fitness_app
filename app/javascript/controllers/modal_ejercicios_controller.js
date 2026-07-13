import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Biblioteca de ejercicios en un popup (5.7b, rediseño 5.11): buscador en vivo,
// chips de filtro por músculo, aplicar UN ejercicio a la card destino o la
// SESIÓN completa de un músculo al día entero (Turbo Stream refresca solo ese
// panel). Convive con "autosave" en el mismo elemento.
export default class extends Controller {
  static targets = ["dialogo", "grupo", "buscador", "chip", "vacio"]

  connect() {
    this.musculo = "todos"
  }

  abrir(event) {
    this.destino = event.target.closest("[data-autosave-target='card']")
    this.diaUrl = event.target.closest("[data-dia-url]")?.dataset.diaUrl
    if (this.hasBuscadorTarget) { this.buscadorTarget.value = ""; this.musculo = "todos"; this.pintarChips(); this.filtrar() }
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

  // ── Filtros: texto + músculo ──────────────────────────────────────────
  filtrar() {
    const consulta = this.normalizar(this.buscadorTarget.value)
    let visiblesTotal = 0

    this.grupoTargets.forEach((grupo) => {
      const seccion = grupo.closest("[data-seccion-musculo]")
      if (this.musculo !== "todos" && grupo.dataset.musculo !== this.musculo) {
        seccion.hidden = true
        return
      }
      let visibles = 0
      grupo.querySelectorAll("button[data-nombre]").forEach((boton) => {
        const coincide = this.normalizar(boton.textContent).includes(consulta)
        boton.hidden = !coincide
        if (coincide) visibles++
      })
      seccion.hidden = visibles === 0
      visiblesTotal += visibles
    })

    if (this.hasVacioTarget) this.vacioTarget.classList.toggle("hidden", visiblesTotal > 0)
  }

  filtrarMusculo(event) {
    this.musculo = event.currentTarget.dataset.musculo
    this.pintarChips()
    this.filtrar()
  }

  pintarChips() {
    this.chipTargets.forEach((chip) => {
      const activo = chip.dataset.musculo === this.musculo
      chip.classList.toggle("btn-primary", activo)
      chip.classList.toggle("btn-ghost", !activo)
      chip.classList.toggle("border", !activo)
      chip.classList.toggle("border-base-300", !activo)
    })
  }

  normalizar(texto) {
    return (texto || "").toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "").trim()
  }

  // ── Aplicar un ejercicio a la card destino ────────────────────────────
  aplicar(event) {
    const o = event.currentTarget.dataset
    if (!this.destino) return

    this.fijar("nombre", o.nombre)
    this.fijar("series", o.series)
    this.fijar("repeticiones", o.repeticiones)
    this.fijar("descanso_seg", o.descanso)
    // Enlace al catálogo visual (Fase 6.4); "" limpia el vínculo anterior
    this.fijar("ejercicio_id", o.ejercicioId || "")
    this.dialogoTarget.close()
    this.destino.querySelector("[name$='[nombre]']")
      ?.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // ── Sesión completa: reemplaza el día entero (Fase 5.11) ──────────────
  async aplicarSesion(event) {
    if (!this.diaUrl) return
    const boton = event.currentTarget
    boton.disabled = true

    const respuesta = await fetch(this.diaUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ dia: { sesion_musculo: boton.dataset.musculo } })
    })

    boton.disabled = false
    if (respuesta.ok) {
      Turbo.renderStreamMessage(await respuesta.text())
      this.cerrar()
    } else {
      this.confirmar(boton, "No se pudo aplicar")
    }
  }

  // ── Guardar la card destino como plantilla nueva ──────────────────────
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
    boton.className = "group flex items-center justify-between gap-2 rounded-xl border border-base-300 px-3 py-2 text-left text-sm transition-colors hover:border-volt-d/50 hover:bg-volt/5"
    boton.dataset.action = "modal-ejercicios#aplicar"
    boton.dataset.nombre = plantilla.nombre
    boton.dataset.series = plantilla.series
    boton.dataset.repeticiones = plantilla.repeticiones
    boton.dataset.descanso = plantilla.descanso_seg
    boton.innerHTML = `<span class="min-w-0 flex-1 truncate font-medium">${plantilla.nombre}</span><span class="shrink-0 rounded-full bg-volt/15 px-2 py-0.5 text-xs font-bold text-volt-d">${plantilla.series}×${plantilla.repeticiones}</span>`
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
