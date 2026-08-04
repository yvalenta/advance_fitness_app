import { Controller } from "@hotwired/stimulus"

// Modo sesión (Fase 14.3): máquina de estados de la pantalla de entrenamiento.
// Lee los ejercicios del <script type="application/json">, marca series al
// tap, corre el cronómetro de descanso contra un timestamp real (sobrevive al
// throttling de pestañas en segundo plano: cada tick recalcula desde Date.now)
// y al final registra cada ejercicio ejecutado contra el endpoint existente
// de registros de entrenamiento — un POST secuencial por ejercicio.
export default class extends Controller {
  static targets = ["datos", "ejercicio", "siguiente", "descanso", "cuenta", "anillo",
                    "proximo", "progresoTexto", "progresoBarra", "resumen",
                    "duracion", "seriesHechas", "volumen", "botonHecho", "errorGuardado"]
  static values = { registroUrl: String, salidaUrl: String }

  connect() {
    this.datos = JSON.parse(this.datosTarget.textContent)
    this.ejercicios = this.datos.ejercicios
    this.actual = 0
    this.hechas = this.ejercicios.map(() => 0)
    this.inicio = Date.now()
    this.circunferencia = 2 * Math.PI * 54 // r=54 del anillo SVG (viewBox 120)
  }

  disconnect() { this.detenerTimer() }

  // ── Series ──────────────────────────────────────────────────────────────
  marcarSerie(event) {
    const chip = event.currentTarget
    if (chip.dataset.hecha) return

    chip.dataset.hecha = "1"
    chip.classList.remove("btn-outline")
    chip.classList.add("btn-primary")
    chip.textContent = `✓ ${chip.textContent.trim()}`

    this.hechas[this.actual] += 1
    if (this.hechas[this.actual] >= this.ejercicios[this.actual].series) {
      this.siguienteTargets[this.actual].hidden = false
    } else {
      this.iniciarDescanso(this.ejercicios[this.actual].descanso_seg)
    }
  }

  // ── Cronómetro de descanso ──────────────────────────────────────────────
  iniciarDescanso(segundos) {
    this.duracionDescanso = segundos
    this.fin = Date.now() + segundos * 1000
    this.panelActual().hidden = true
    this.proximoTarget.textContent = this.proximaSerieTexto()
    this.descansoTarget.hidden = false
    this.pintarDescanso()
    this.timer = setInterval(() => this.pintarDescanso(), 250)
  }

  pintarDescanso() {
    const restante = Math.max(0, Math.ceil((this.fin - Date.now()) / 1000))
    this.cuentaTarget.textContent = restante
    const fraccion = this.duracionDescanso > 0 ? restante / this.duracionDescanso : 0
    this.anilloTarget.style.strokeDashoffset = this.circunferencia * (1 - fraccion)
    if (restante <= 0) this.terminarDescanso({ vibrar: true })
  }

  extenderDescanso() {
    this.fin += 30000
    this.duracionDescanso += 30
    this.pintarDescanso()
  }

  saltarDescanso() { this.terminarDescanso({ vibrar: false }) }

  terminarDescanso({ vibrar }) {
    this.detenerTimer()
    if (vibrar && "vibrate" in navigator) navigator.vibrate([200, 100, 200])
    this.descansoTarget.hidden = true
    this.panelActual().hidden = false
    this.resaltarProximaSerie()
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

  // Volumen = series hechas × reps (límite inferior del rango) × kg sugerido.
  volumenKg() {
    return Math.round(this.ejercicios.reduce((suma, ejercicio, i) =>
      suma + this.hechas[i] * (parseInt(ejercicio.repeticiones, 10) || 0) * (ejercicio.peso_sugerido_kg || 0), 0))
  }

  formatoDuracion(ms) {
    const totalSeg = Math.round(ms / 1000)
    return `${Math.floor(totalSeg / 60)}:${String(totalSeg % 60).padStart(2, "0")}`
  }

  // El proxy de media puede no tener el GIF: se oculta el <img> y queda el
  // ícono de respaldo que está pintado detrás.
  ocultarMedia(event) { event.currentTarget.hidden = true }
}
