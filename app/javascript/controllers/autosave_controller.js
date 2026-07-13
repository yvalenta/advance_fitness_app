import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Editor de plan nutricional por comida con autosave tolerante a fallos.
// Cada card guarda sola (debounce) y muestra su estado: editando → guardando
// → guardado, o error con "Reintentar" sin perder lo escrito. El total y los
// macros se recalculan en vivo; el botón Publicar se bloquea si algo está a
// medio guardar o en error.
export default class extends Controller {
  static targets = ["card", "estado", "total", "macros", "barra", "publicar", "global"]

  connect() {
    this.temporizadores = new WeakMap()
    this.enError = new Set()
    this.guardando = new Set()
    this.recalcular()
    this.actualizarPublicar()
  }

  // input en cualquier campo → programa el guardado de esa card
  programar(event) {
    const card = event.target.closest("[data-autosave-target='card']")
    if (!card) return
    this.recalcular()
    this.marcar(card, "editando", "Sin guardar")

    clearTimeout(this.temporizadores.get(card))
    this.temporizadores.set(card, setTimeout(() => this.guardar(card), 600))
  }

  async guardar(card) {
    clearTimeout(this.temporizadores.get(card))
    this.guardando.add(card)
    this.enError.delete(card)
    this.marcar(card, "guardando", "Guardando…")
    this.actualizarPublicar()

    try {
      const respuesta = await fetch(card.dataset.url, {
        method: "PATCH",
        headers: this.cabeceras,
        body: JSON.stringify({ [card.dataset.clave || this.clave]: this.camposDe(card) })
      })
      const datos = await respuesta.json().catch(() => ({}))

      if (respuesta.ok) {
        this.marcar(card, "guardado", "Guardado ✓")
        if (datos.kcal_diarias != null) this.fijarTotal(datos.kcal_diarias)
        setTimeout(() => { if (!this.guardando.has(card) && !this.enError.has(card)) this.marcar(card, "idle", "") }, 2000)
      } else {
        this.fallar(card, datos.error || "No se pudo guardar")
      }
    } catch {
      this.fallar(card, "Sin conexión")
    } finally {
      this.guardando.delete(card)
      this.actualizarPublicar()
    }
  }

  reintentar(event) {
    this.guardar(event.target.closest("[data-autosave-target='card']"))
  }

  async agregar(event) {
    event.preventDefault()
    // La URL de alta puede venir por botón (rutina: una por día) o del controlador.
    const url = event.currentTarget.dataset.url || this.data.get("crearUrl")
    await this.enviarEstructura(url, "POST")
  }

  async eliminar(event) {
    event.preventDefault()
    // window.confirm no hace nada en iOS con la app agregada a inicio
    // (Fase 6.9): se reemplaza por el diálogo global de confirmación.
    if (!(await window.confirmarAccion("¿Eliminar este elemento del plan?"))) return
    const card = event.target.closest("[data-autosave-target='card']")
    await this.enviarEstructura(card.dataset.url, "DELETE")
  }

  // Alta/baja cambian los índices: el servidor (fuente de verdad) responde
  // turbo_stream con la sección ya recalculada, sin recargar la página.
  async enviarEstructura(url, metodo) {
    this.marcarGlobal("Guardando…")
    try {
      const respuesta = await fetch(url, {
        method: metodo,
        headers: { ...this.cabeceras, Accept: "text/vnd.turbo-stream.html" }
      })
      if (respuesta.ok) {
        Turbo.renderStreamMessage(await respuesta.text())
        this.marcarGlobal("Todo guardado ✓")
      } else {
        this.marcarGlobal("No se pudo guardar — reintenta")
      }
    } catch {
      this.marcarGlobal("Sin conexión — reintenta")
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────

  // Genérico: lee todos los inputs del card usando la clave entre corchetes
  // del name (p. ej. name="comida[kcal]" o name="ejercicio[series]").
  camposDe(card) {
    const campos = {}
    card.querySelectorAll("[name*='['][name$=']']").forEach((input) => {
      const clave = input.name.match(/\[([^\]]+)\]$/)?.[1]
      if (clave) campos[clave] = input.value
    })
    return campos
  }

  get clave() {
    return this.data.get("clave") || "comida"
  }

  marcar(card, estado, texto) {
    const badge = card.querySelector("[data-autosave-target='estado']")
    if (!badge) return
    badge.dataset.estado = estado
    badge.textContent = texto
    badge.hidden = estado === "idle"
    badge.classList.remove("badge-ghost", "badge-info", "badge-success", "badge-error")
    const clase = { editando: "badge-ghost", guardando: "badge-info", guardado: "badge-success", error: "badge-error" }[estado]
    if (clase) badge.classList.add(clase)
    badge.classList.toggle("cursor-pointer", estado === "error")
  }

  fallar(card, texto) {
    this.enError.add(card)
    this.marcar(card, "error", `${texto} · Reintentar`)
  }

  fijarTotal(kcal) {
    if (this.hasTotalTarget) this.totalTarget.textContent = Math.round(kcal).toLocaleString("es-CO")
  }

  recalcular() {
    const suma = (nombre, factor = 1) => this.cardTargets.reduce((total, card) => {
      const campo = card.querySelector(`[name$="[${nombre}]"]`)
      return total + (parseFloat(campo?.value) || 0) * factor
    }, 0)

    const proteinas = suma("proteinas_g"), carbohidratos = suma("carbohidratos_g"), grasas = suma("grasas_g")
    this.fijarTotal(suma("kcal"))
    if (this.hasMacrosTarget) {
      this.macrosTarget.textContent = `P ${Math.round(proteinas)}g · C ${Math.round(carbohidratos)}g · G ${Math.round(grasas)}g`
    }
    const kcalMacros = proteinas * 4 + carbohidratos * 4 + grasas * 9
    if (kcalMacros > 0 && this.barraTargets.length === 3) {
      const [ p, c, g ] = this.barraTargets
      p.style.width = `${(proteinas * 4 / kcalMacros) * 100}%`
      c.style.width = `${(carbohidratos * 4 / kcalMacros) * 100}%`
      g.style.width = `${(grasas * 9 / kcalMacros) * 100}%`
    }
  }

  actualizarPublicar() {
    const ocupado = this.guardando.size > 0 || this.enError.size > 0
    if (this.hasPublicarTarget) this.publicarTarget.disabled = ocupado
    this.marcarGlobal(ocupado ? (this.enError.size ? "Hay cambios sin guardar" : "Guardando…") : "Todo guardado ✓")
  }

  marcarGlobal(texto) {
    if (this.hasGlobalTarget) this.globalTarget.textContent = texto
  }

  get cabeceras() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
    }
  }
}
