import { Controller } from "@hotwired/stimulus"

// Checklist interactivo del plan nutricional: marcar comidas anima el total de
// kcal, la barra de progreso contra el objetivo y habilita registrar ese total
// como el consumo del día (upsert de la Fase 4). Desde la Fase 5.8 el miembro
// puede ajustar las kcal que realmente comió por comida y anotar un cambio; el
// total y el detalle ({ comidas: [{nombre, kcal, nota}] }) viajan al registro.
// Desde la Fase 14.4 cada card del grid por tipo (desayuno/almuerzo/cena/
// snack/otros) muestra su consumo en vivo, y los gramos de macros de las
// comidas marcadas viajan en hidden fields junto al total.
export default class extends Controller {
  static targets = [
    "comida", "consumidas", "barra", "estado", "boton", "kcalInput",
    "segmento", "tarjeta", "kcal", "nota", "detalle", "alerta", "hint",
    "tipoKcal", "proteinasInput", "carbohidratosInput", "grasasInput"
  ]
  static values = { objetivo: Number }

  // Tolerancia antes de alertar desviación contra el objetivo (Fase 5.11)
  static TOLERANCIA = 0.05

  // Macros que viajan al registro (mismo orden que sus hidden fields)
  static MACROS = ["proteinas", "carbohidratos", "grasas"]

  connect() {
    // Despliega la barra de macros (los anchos finales vienen en data-pct)
    requestAnimationFrame(() => {
      this.segmentoTargets.forEach((segmento) => (segmento.style.width = `${segmento.dataset.pct}%`))
    })
    this.actualizar()
  }

  actualizar() {
    const marcadas = this.comidaTargets.filter((comida) => comida.checked)
    const total = marcadas.reduce((suma, comida) => suma + this.kcalDe(comida), 0)
    const completas = this.comidaTargets.length > 0 && this.comidaTargets.every((comida) => comida.checked)
    const progreso = this.objetivoValue > 0 ? Math.min((total / this.objetivoValue) * 100, 100) : 0

    this.animarNumero(this.consumidasTarget, total)
    if (this.hasBarraTarget) this.barraTarget.style.width = `${progreso}%`
    if (this.hasEstadoTarget) this.estadoTarget.hidden = !completas

    if (this.hasBotonTarget) {
      this.botonTarget.disabled = total === 0
      this.botonTarget.textContent =
        total === 0 ? "Marca lo que comiste hoy" : `Registrar ${total.toLocaleString("es-CO")} kcal como mi consumo de hoy`
    }
    if (this.hasKcalInputTarget) this.kcalInputTarget.value = total
    if (this.hasDetalleTarget) {
      this.detalleTarget.value = JSON.stringify({ comidas: marcadas.map((comida) => this.detalleDe(comida)) })
    }
    this.actualizarTipos(marcadas)
    this.actualizarMacros(marcadas)
    this.alertar(total, completas)
    this.actualizarHints()
  }

  // Consumo por tipo de comida (Fase 14.4): cada card del grid 2×2 muestra
  // las kcal marcadas de su tipo (desayuno/almuerzo/cena/snack/otros).
  actualizarTipos(marcadas) {
    if (!this.hasTipoKcalTarget) return

    const porTipo = {}
    marcadas.forEach((comida) => {
      const tipo = comida.dataset.tipo || "otros"
      porTipo[tipo] = (porTipo[tipo] || 0) + this.kcalDe(comida)
    })
    this.tipoKcalTargets.forEach((contador) => this.animarNumero(contador, porTipo[contador.dataset.tipo] || 0))
  }

  // Macros del consumo real (Fase 14.4): suma los gramos del plan de las
  // comidas marcadas y los deja en los hidden fields del registro. Si el plan
  // no trae macros (todo en 0) viajan vacíos y el backend guarda nil, no 0.
  actualizarMacros(marcadas) {
    const sumas = this.constructor.MACROS.map((macro) =>
      marcadas.reduce((suma, comida) => suma + (Number(comida.dataset[macro]) || 0), 0))
    const hayDatos = sumas.some((gramos) => gramos > 0)

    const inputs = [
      this.hasProteinasInputTarget && this.proteinasInputTarget,
      this.hasCarbohidratosInputTarget && this.carbohidratosInputTarget,
      this.hasGrasasInputTarget && this.grasasInputTarget
    ]
    inputs.forEach((input, indice) => {
      if (input) input.value = hayDatos ? sumas[indice] : ""
    })
  }

  // Alerta viva (Fase 5.11): editar por encima de lo sugerido alerta en rojo;
  // quedarse por debajo (con todo marcado) avisa que no está alineado.
  alertar(total, completas) {
    if (!this.hasAlertaTarget || this.objetivoValue <= 0) return

    const tolerancia = this.objetivoValue * this.constructor.TOLERANCIA
    const delta = total - this.objetivoValue
    const alerta = this.alertaTarget

    if (total > 0 && delta > tolerancia) {
      alerta.hidden = false
      alerta.className = "mt-2 rounded-lg bg-error/10 px-3 py-2 text-xs font-semibold text-error"
      alerta.textContent = `+${delta.toLocaleString("es-CO")} kcal sobre lo sugerido — no alineado con tu objetivo.`
    } else if (completas && delta < -tolerancia) {
      alerta.hidden = false
      alerta.className = "mt-2 rounded-lg bg-warning/10 px-3 py-2 text-xs font-semibold text-warning"
      alerta.textContent = `Te faltan ${Math.abs(delta).toLocaleString("es-CO")} kcal para tu objetivo — por debajo de lo planificado.`
    } else {
      alerta.hidden = true
    }
  }

  // Hint por comida cuando la kcal editada difiere de la sugerida del plan
  actualizarHints() {
    this.hintTargets.forEach((hint) => {
      const tarjeta = hint.closest("[data-plan-nutricional-target='tarjeta']")
      const check = tarjeta?.querySelector("[data-plan-nutricional-target='comida']")
      if (!check?.checked) { hint.hidden = true; return }

      const delta = this.kcalDe(check) - Number(check.dataset.kcal)
      if (delta > 0) {
        hint.hidden = false
        hint.className = "w-full text-xs font-semibold text-error"
        hint.textContent = `+${delta.toLocaleString("es-CO")} kcal sobre lo sugerido en esta comida.`
      } else if (delta < 0) {
        hint.hidden = false
        hint.className = "w-full text-xs font-semibold text-warning"
        hint.textContent = `${Math.abs(delta).toLocaleString("es-CO")} kcal por debajo de lo sugerido en esta comida.`
      } else {
        hint.hidden = true
      }
    })
  }

  // Las kcal de una comida marcada: el ajuste del miembro si existe, si no las
  // kcal del plan (dataset del checkbox).
  kcalDe(comida) {
    const editable = this.tarjetaDe(comida)?.querySelector("[data-plan-nutricional-target='kcal']")
    const valor = editable ? Number(editable.value) : Number(comida.dataset.kcal)
    return Number.isFinite(valor) && valor > 0 ? Math.round(valor) : 0
  }

  detalleDe(comida) {
    const nota = this.tarjetaDe(comida)?.querySelector("[data-plan-nutricional-target='nota']")
    return { nombre: comida.dataset.nombre, kcal: this.kcalDe(comida), nota: nota?.value.trim() || "" }
  }

  tarjetaDe(comida) {
    return comida.closest("[data-plan-nutricional-target='tarjeta']")
  }

  // Count-up con easing cúbico — el número "corre" hasta el valor nuevo
  animarNumero(elemento, hasta) {
    const desde = Number(elemento.dataset.actual || 0)
    if (desde === hasta) return

    const inicio = performance.now()
    const duracion = 450
    const paso = (ahora) => {
      const avance = Math.min((ahora - inicio) / duracion, 1)
      const valor = Math.round(desde + (hasta - desde) * (1 - Math.pow(1 - avance, 3)))
      elemento.textContent = valor.toLocaleString("es-CO")
      if (avance < 1) requestAnimationFrame(paso)
    }
    requestAnimationFrame(paso)
    elemento.dataset.actual = hasta
  }
}
