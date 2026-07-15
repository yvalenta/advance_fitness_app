# Analiza con IA la sesión de entrenamiento completa de un día (SDD §18,
# Fase 12): todos los ejercicios y series de un mismo registro_entrenamiento,
# con el historial de las últimas semanas como contexto de tendencia. Corre
# en Solid Queue: el request nunca espera a la IA. Revalida la suscripción,
# el nivel de análisis y el mínimo de datos EN LA BASE antes de llamar a la
# API. Los fallos NO se re-lanzan: quedan como estado "fallido" con su
# mensaje, mismo patrón de GenerarPlanJob.
class AnalizarEntrenamientoJob < ApplicationJob
  queue_as :default

  def perform(registro_entrenamiento_id)
    registro = RegistroEntrenamiento.find_by(id: registro_entrenamiento_id)
    return unless registro

    feedback = registro.feedback_ia || registro.create_feedback_ia!(estado: "pendiente")

    unless registro.user.premium?
      return feedback.fallar!("Sin suscripción personalizada activa")
    end

    feedback.marcar_generando!

    resultado = GeneradorFeedbackIa.generar(
      series: series_del_dia(registro),
      historial: HistorialEntrenamiento.resumen_semanal(registro.user)
    )

    feedback.completar!(
      diagnostico: resultado[:diagnostico],
      analisis: resultado[:analisis],
      accion_recomendada: resultado[:accion_recomendada],
      modelo: resultado[:modelo]
    )
  rescue StandardError => error
    # Sin conexión no hay cómo persistir el fallo — se re-lanza para que el
    # retry_on de ApplicationJob lo reintente pasada la ventana de deploy.
    raise if error.is_a?(ActiveRecord::ConnectionNotEstablished)
    feedback&.fallar!(error.message)
  end

  private
    # Todos los ejercicios y series de ESE registro (el día completo), no un
    # recorte global histórico — así se puede evaluar la sesión como unidad.
    def series_del_dia(registro)
      registro.detalles.includes(:ejercicio).order(:ejercicio_id, :serie).map do |detalle|
        { ejercicio: detalle.ejercicio.nombre, fecha: registro.fecha.iso8601,
          serie: detalle.serie, repeticiones: detalle.repeticiones,
          peso_kg: detalle.peso_kg, rpe: detalle.rpe }
      end
    end
end
