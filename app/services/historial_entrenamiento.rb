# Contexto histórico corto para el Analista de Performance (Fase 12): el
# análisis en sí es de la sesión del día completo (ver AnalizarEntrenamientoJob),
# pero el diagnóstico de progreso/estancamiento necesita comparar contra
# semanas previas. PORO puro, mismo patrón que ResumenAdherencia.
module HistorialEntrenamiento
  # Agrupación por semana CALENDARIO (beginning_of_week). Contrato estable:
  # el Analista de Performance (§18.7) exige 3 semanas de datos comparables
  # sin importar el plan vigente — no cambiar su forma.
  def self.resumen_semanal(user, semanas: 4)
    detalles = detalles_en_rango(user, semanas)
    return [] if detalles.none?

    detalles.group_by { |d| d.registro_entrenamiento.fecha.beginning_of_week }
            .sort.map do |semana, del_grupo|
      { semana: semana.iso8601, series: del_grupo.size,
        volumen_kg: del_grupo.sum(&:volumen_kg).round(1) }
    end
  end

  # Etapa 14.10: variante agrupada por semana del MESOCICLO cuando el plan
  # vigente es v2 (más de una semana); sin plan v2 cae a la agrupación
  # calendario clásica de arriba. Los detalles fuera del ciclo (previos al
  # plan o posteriores a su fin) se excluyen: pertenecen a otro mesociclo y
  # contaminarían la lectura del ciclo en curso.
  def self.resumen_mesociclo(user, semanas: 4)
    plan = plan_v2_vigente(user)
    return resumen_semanal(user, semanas: semanas) unless plan

    metadatos = semanas_del(plan)
    detalles_en_rango(user, semanas)
      .group_by { |d|
        # Enteros sin clamp (API 14.7): fuera de 1..total = fuera del ciclo,
        # excluido — misma normalización que ResumenAdherencia.
        numero = calendario.semana_de(plan, d.registro_entrenamiento.fecha)
        numero.is_a?(Integer) && numero.between?(1, metadatos.size) ? numero : nil
      }
      .except(nil).sort.map do |numero, del_grupo|
        meta = ResumenAdherencia.meta_de(metadatos, numero) || {}
        { semana: numero,
          etiqueta: ResumenAdherencia.dato(meta, :etiqueta),
          descarga: ResumenAdherencia.dato(meta, :descarga) == true,
          series: del_grupo.size, volumen_kg: del_grupo.sum(&:volumen_kg).round(1) }
      end
  end

  # Un plan v2 tiene mesociclo real (más de una semana); el v1 es la semana
  # identidad y para él la agrupación calendario ya cuenta la historia.
  def self.plan_v2_vigente(user)
    plan = user.plan_aprobado
    plan if plan && semanas_del(plan).size > 1
  end

  def self.detalles_en_rango(user, semanas)
    desde = Date.current.beginning_of_week - (semanas - 1).weeks
    DetalleEntrenamiento.joins(:registro_entrenamiento)
                        .where(registro_entrenamiento: { user_id: user.id, fecha: desde..Date.current })
                        .includes(:registro_entrenamiento)
  end

  # ── Resolución contract-first (14.10) — ver ResumenAdherencia ────────────
  def self.calendario
    ResumenAdherencia.calendario
  end

  def self.semanas_del(plan)
    ResumenAdherencia.semanas_del(plan)
  end
end
