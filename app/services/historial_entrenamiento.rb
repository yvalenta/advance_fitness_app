# Contexto histórico corto para el Analista de Performance (Fase 12): el
# análisis en sí es de la sesión del día completo (ver AnalizarEntrenamientoJob),
# pero el diagnóstico de progreso/estancamiento necesita comparar contra
# semanas previas. PORO puro, mismo patrón que ResumenAdherencia.
module HistorialEntrenamiento
  def self.resumen_semanal(user, semanas: 4)
    desde = Date.current.beginning_of_week - (semanas - 1).weeks
    detalles = DetalleEntrenamiento.joins(:registro_entrenamiento)
                                   .where(registro_entrenamiento: { user_id: user.id, fecha: desde..Date.current })
                                   .includes(:registro_entrenamiento)
    return [] if detalles.none?

    detalles.group_by { |d| d.registro_entrenamiento.fecha.beginning_of_week }
            .sort.map do |semana, del_grupo|
      { semana: semana.iso8601, series: del_grupo.size,
        volumen_kg: del_grupo.sum(&:volumen_kg).round(1) }
    end
  end
end
