import { Controller } from "@hotwired/stimulus"

// Modo sesión (Fase 14.3): máquina de estados de la pantalla de entrenamiento.
// Lee los ejercicios del <script type="application/json">, marca series al
// tap, corre el cronómetro de descanso contra un timestamp real (sobrevive al
// throttling de pestañas en segundo plano: cada tick recalcula desde Date.now)
// y al final registra cada ejercicio ejecutado contra el endpoint existente
// de registros de entrenamiento — un POST secuencial por ejercicio.
//
// Fase 20 agrega dos variantes sobre el mismo cronómetro compartido:
//   - Ejercicios por tiempo (tipo: "tiempo"): el tap en "Serie N" no registra
//     al toque, ARRANCA el cronómetro como trabajo cronometrado (duración =
//     `repeticiones` reusado como segundos, SDD Nota 27); al terminar (solo
//     o por "Listo") registra los segundos REALES sostenidos, no siempre el
//     objetivo completo.
//   - Superseries (grupo_superserie): dos ejercicios con el mismo grupo se
//     alternan serie a serie SIN descanso entre ellos — el descanso llega
//     solo al cerrar la ronda (cuando ambos ya hicieron esa serie).
export default class extends Controller {
  static targets = ["datos", "ejercicio", "siguiente", "descanso", "cuenta", "anillo",
                    "tituloCronometro", "botonSaltar", "proximo", "progresoTexto", "progresoBarra",
                    "resumen", "duracion", "seriesHechas", "volumen", "botonHecho", "errorGuardado"]
  static values = { registroUrl: String, detallesUrl: String, salidaUrl: String }

  connect() {
    this.datos = JSON.parse(this.datosTarget.textContent)
    this.ejercicios = this.datos.ejercicios
    this.actual = 0
    this.hechas = this.ejercicios.map(() => 0)
    this.inicio = Date.now()
    this.circunferencia = 2 * Math.PI * 54 // r=54 del anillo SVG (viewBox 120)
    this.parejas = this.mapaDeParejas()
    this.enTrabajo = false
    this.restaurarRegistradas()
  }

  disconnect() { this.detenerTimer() }

  // grupo_superserie → [índiceA, índiceB] (solo pares; más de dos con el
  // mismo grupo se ignora, el primero y el último "ganan" el emparejamiento).
  mapaDeParejas() {
    const porGrupo = {}
    this.ejercicios.forEach((ejercicio, indice) => {
      if (!ejercicio.grupo_superserie) return
      ;(porGrupo[ejercicio.grupo_superserie] ||= []).push(indice)
    })
    const parejas = {}
    Object.values(porGrupo).forEach(([ a, b ]) => {
      if (a == null || b == null) return
      parejas[a] = b
      parejas[b] = a
    })
    return parejas
  }

  parejaDe(indice) { return indice in this.parejas ? this.parejas[indice] : null }

  // ── Series ──────────────────────────────────────────────────────────────
  marcarSerie(event) {
    const chip = event.currentTarget
    if (chip.dataset.hecha) return

    const ejercicio = this.ejercicios[this.actual]
    if (ejercicio.tipo === "tiempo") {
      this.iniciarTrabajo(chip, ejercicio)
    } else {
      this.completarSerie(chip)
    }
  }

  // Registra la serie (chip ya marcado en pintarHecha) y decide qué sigue:
  // si el ejercicio actual tiene pareja de superserie, se alterna sin
  // descanso; si no, el comportamiento de siempre (descanso entre series
  // propias, "Siguiente" al completar todas).
  completarSerie(chip) {
    this.pintarHecha(chip)
    this.registrarSerie(Number(chip.dataset.serie) + 1)
    this.hechas[this.actual] += 1

    const pareja = this.parejaDe(this.actual)
    if (pareja !== null) {
      this.avanzarSuperserie(pareja)
      return
    }

    if (this.hechas[this.actual] >= this.ejercicios[this.actual].series) {
      this.siguienteTargets[this.actual].hidden = false
    } else {
      this.iniciarCronometro(this.ejercicios[this.actual].descanso_seg)
    }
  }

  pintarHecha(chip) {
    chip.dataset.hecha = "1"
    chip.classList.remove("btn-outline")
    chip.classList.add("btn-primary")
    chip.textContent = `✓ ${chip.textContent.trim()}`
  }

  // Re-visita del mismo día (Fase 18l): los chips ya registrados en el
  // servidor amanecen marcados — re-taparlos no duplica (el POST es
  // idempotente por serie, y el chip marcado ni siquiera dispara).
  restaurarRegistradas() {
    this.ejercicios.forEach((ejercicio, i) => {
      const registradas = ejercicio.series_registradas || 0
      if (registradas <= 0) return

      const chips = this.ejercicioTargets[i].querySelectorAll("[data-serie]")
      chips.forEach((chip) => {
        if (Number(chip.dataset.serie) < registradas) this.pintarHecha(chip)
      })
      this.hechas[i] = Math.min(registradas, ejercicio.series)
      if (this.hechas[i] >= ejercicio.series) this.siguienteTargets[i].hidden = false
    })
  }

  // Registro cuantitativo por serie (Fase 18l, solo premium — sin URL no
  // envía): reps del plan (límite inferior del rango) y kg de la vez pasada
  // o el sugerido de estreno. Best-effort: un fallo de red jamás interrumpe
  // el entrenamiento — el índice único por serie evita duplicados.
  // Fase 20: un ejercicio por tiempo registra los SEGUNDOS reales sostenidos
  // (this.segundosTrabajoReales), no el objetivo si se cortó antes/después.
  registrarSerie(numeroSerie) {
    if (!this.detallesUrlValue) return
    const ejercicio = this.ejercicios[this.actual]
    if (!ejercicio.ejercicio_id && !ejercicio.nombre) return

    const reps = ejercicio.tipo === "tiempo"
      ? (this.segundosTrabajoReales || parseInt(ejercicio.repeticiones, 10) || 1)
      : (parseInt(ejercicio.repeticiones, 10) || 1)
    const cuerpo = {
      fecha: this.datos.fecha, ejercicio_id: ejercicio.ejercicio_id, nombre: ejercicio.nombre,
      serie: numeroSerie, repeticiones: reps, uid: ejercicio.uid
    }
    if (ejercicio.peso_registro_kg > 0) cuerpo.peso_kg = ejercicio.peso_registro_kg

    fetch(this.detallesUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify(cuerpo)
    }).then(async (r) => {
      // Si la serie rompió un récord, la respuesta trae el toast de
      // celebración como turbo-stream (Fase 18n) — se renderiza acá mismo,
      // en plena sesión, que es donde el récord acaba de pasar.
      const texto = await r.text()
      if (texto.includes("turbo-stream") && window.Turbo) window.Turbo.renderStreamMessage(texto)
    }).catch(() => {})
  }

  // ── Superseries (Fase 20) ────────────────────────────────────────────────
  // El orden lo controla el panel visible: el miembro solo puede tapear el
  // chip del ejercicio que está mostrando, así que el estado "de quién es
  // el turno" es siempre this.actual — no hace falta rastrear más.
  avanzarSuperserie(pareja) {
    const esPrimeroDelPar = this.actual < pareja
    if (esPrimeroDelPar) {
      // A acaba de hacer su serie → pasa a B sin descanso, misma ronda.
      this.panelActual().hidden = true
      this.actual = pareja
      this.panelActual().hidden = false
      this.resaltarProximaSerie()
      return
    }

    // B acaba de hacer su serie → cierra la ronda del par.
    const primero = pareja
    const rondaCompleta = this.hechas[this.actual] >= this.ejercicios[this.actual].series &&
                          this.hechas[primero] >= this.ejercicios[primero].series
    if (rondaCompleta) {
      this.siguienteTargets[this.actual].hidden = false
      return
    }

    this.panelActual().hidden = true
    this.actual = primero
    this.iniciarCronometro(this.ejercicios[primero].descanso_seg) // vuelve a mostrar A al terminar
  }

  // ── Cronómetro compartido: descanso o trabajo cronometrado (Fase 20) ────
  iniciarCronometro(segundos) {
    this.enTrabajo = false
    this.duracionDescanso = segundos
    this.fin = Date.now() + segundos * 1000
    this.panelActual().hidden = true
    this.tituloCronometroTarget.textContent = "Descanso"
    this.botonSaltarTarget.textContent = "Saltar"
    this.proximoTarget.textContent = this.proximaSerieTexto()
    this.descansoTarget.hidden = false
    this.pintarDescanso()
    this.timer = setInterval(() => this.pintarDescanso(), 250)
  }

  // Ejercicio por tiempo (Fase 20): el chip arranca el trabajo en vez de
  // registrar al toque — mismo cronómetro visual, título/botón distintos, y
  // al terminar registra la serie (segundos reales) en vez de solo avisar.
  iniciarTrabajo(chip, ejercicio) {
    this.enTrabajo = true
    this.chipEnTrabajo = chip
    this.inicioTrabajo = Date.now()
    const segundos = parseInt(ejercicio.repeticiones, 10) || 30
    this.duracionDescanso = segundos
    this.fin = Date.now() + segundos * 1000
    this.panelActual().hidden = true
    this.tituloCronometroTarget.textContent = "Trabajo"
    this.botonSaltarTarget.textContent = "Listo"
    this.proximoTarget.textContent = ejercicio.nombre
    this.descansoTarget.hidden = false
    this.pintarDescanso()
    this.timer = setInterval(() => this.pintarDescanso(), 250)
  }

  pintarDescanso() {
    const restante = Math.max(0, Math.ceil((this.fin - Date.now()) / 1000))
    this.cuentaTarget.textContent = restante
    const fraccion = this.duracionDescanso > 0 ? restante / this.duracionDescanso : 0
    this.anilloTarget.style.strokeDashoffset = this.circunferencia * (1 - fraccion)
    if (restante <= 0) {
      if (this.enTrabajo) this.terminarTrabajo()
      else this.terminarDescanso({ vibrar: true })
    }
  }

  extenderDescanso() {
    this.fin += 30000
    this.duracionDescanso += 30
    this.pintarDescanso()
  }

  // Un solo botón para ambos modos: "Saltar" corta el descanso, "Listo"
  // cierra el trabajo cronometrado antes de tiempo (registra lo sostenido).
  saltarCronometro() {
    if (this.enTrabajo) this.terminarTrabajo()
    else this.terminarDescanso({ vibrar: false })
  }

  terminarDescanso({ vibrar }) {
    this.detenerTimer()
    if (vibrar && "vibrate" in navigator) navigator.vibrate([200, 100, 200])
    this.descansoTarget.hidden = true
    this.panelActual().hidden = false
    this.resaltarProximaSerie()
  }

  terminarTrabajo() {
    this.detenerTimer()
    if ("vibrate" in navigator) navigator.vibrate([200, 100, 200])
    this.segundosTrabajoReales = Math.max(1, Math.round((Date.now() - this.inicioTrabajo) / 1000))
    this.descansoTarget.hidden = true
    this.enTrabajo = false
    this.panelActual().hidden = false
    this.completarSerie(this.chipEnTrabajo)
    this.segundosTrabajoReales = null
    this.chipEnTrabajo = null
  }

  detenerTimer() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  // ── Avance entre ejercicios ─────────────────────────────────────────────
  siguiente() {
    this.panelActual().hidden = true
    if (this.actual + 1 < this.ejercicios.length) {
      this.actual += 1
      this.panelActual().hidden = false
      this.actualizarProgreso()
      this.resaltarProximaSerie()
    } else {
      this.mostrarResumen()
    }
  }

  actualizarProgreso() {
    this.progresoTextoTarget.textContent = `Ejercicio ${this.actual + 1} de ${this.ejercicios.length}`
    this.progresoBarraTarget.style.width = `${((this.actual + 1) / this.ejercicios.length) * 100}%`
  }

  // ── Resumen y registro del día ──────────────────────────────────────────
  mostrarResumen() {
    this.resumenTarget.hidden = false
    this.progresoTextoTarget.textContent = "Sesión completada"
    this.progresoBarraTarget.style.width = "100%"
    this.duracionTarget.textContent = this.formatoDuracion(Date.now() - this.inicio)
    this.seriesHechasTarget.textContent = this.hechas.reduce((suma, n) => suma + n, 0)
    this.volumenTarget.textContent = this.volumenKg().toLocaleString("es-CO")
  }

  // Un POST por ejercicio ejecutado, secuencial: el upsert del endpoint
  // comparte la fila del día y así no se pisan escrituras concurrentes.
  async marcarDia() {
    this.botonHechoTarget.disabled = true
    this.botonHechoTarget.textContent = "Guardando…"
    this.errorGuardadoTarget.hidden = true

    try {
      for (const [i, ejercicio] of this.ejercicios.entries()) {
        if (this.hechas[i] === 0) continue
        const respuesta = await fetch(this.registroUrlValue, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
          },
          body: JSON.stringify({
            fecha: this.datos.fecha, uid: ejercicio.uid, indice: ejercicio.indice,
            hecho: true, nombre: ejercicio.nombre
          })
        })
        if (!respuesta.ok) throw new Error(`registro ${ejercicio.uid}`)
      }
      this.botonHechoTarget.textContent = "Guardado ✓"
      this.salir()
    } catch {
      this.botonHechoTarget.disabled = false
      this.botonHechoTarget.textContent = "Reintentar"
      this.errorGuardadoTarget.hidden = false
    }
  }

  salir() {
    if (window.Turbo) {
      window.Turbo.visit(this.salidaUrlValue)
    } else {
      window.location.assign(this.salidaUrlValue)
    }
  }

  // ── Ayudas ──────────────────────────────────────────────────────────────
  panelActual() { return this.ejercicioTargets[this.actual] }

  proximaSerieTexto() {
    const ejercicio = this.ejercicios[this.actual]
    return `Serie ${this.hechas[this.actual] + 1} de ${ejercicio.series} · ${ejercicio.nombre}`
  }

  resaltarProximaSerie() {
    const pendiente = this.panelActual().querySelector("[data-serie]:not([data-hecha])")
    if (pendiente) pendiente.classList.add("ring-2", "ring-volt", "ring-offset-2", "ring-offset-base-100")
  }

  // Volumen = series hechas × reps (límite inferior del rango) × kg — el
  // mismo kg que se registra (vez pasada o sugerido, Fase 18l). Un ejercicio
  // por tiempo no aporta volumen de carga (no hay reps que multiplicar).
  volumenKg() {
    return Math.round(this.ejercicios.reduce((suma, ejercicio, i) => {
      if (ejercicio.tipo === "tiempo") return suma
      return suma + this.hechas[i] * (parseInt(ejercicio.repeticiones, 10) || 0) * (ejercicio.peso_registro_kg || ejercicio.peso_sugerido_kg || 0)
    }, 0))
  }

  formatoDuracion(ms) {
    const totalSeg = Math.round(ms / 1000)
    return `${Math.floor(totalSeg / 60)}:${String(totalSeg % 60).padStart(2, "0")}`
  }

  // El proxy de media puede no tener el GIF: se oculta el <img> y queda el
  // ícono de respaldo que está pintado detrás.
  ocultarMedia(event) { event.currentTarget.hidden = true }
}
