# Analiza con IA el historial cuantitativo de un miembro (SDD §18, Fase
# 11-B). Corre en Solid Queue: el request nunca espera a la IA. Revalida la
# suscripción EN LA BASE antes de llamar a la API. Los fallos NO se
# re-lanzan: quedan como estado "fallido" con su mensaje, mismo patrón de
# GenerarPlanJob.
class AnalizarEntrenamientoJob < ApplicationJob
  queue_as :default

  SERIES_A_ANALIZAR = 20

  def perform(registro_entrenamiento_id)
    registro = RegistroEntrenamiento.find_by(id: registro_entrenamiento_id)
    return unless registro

    feedback = registro.feedback_ia || registro.create_feedback_ia!(estado: "pendiente")

    unless registro.user.premium?
      return feedback.fallar!("Sin suscripción personalizada activa")
    end

    feedback.marcar_generando!

    resultado = GeneradorFeedbackIa.generar(series: series_recientes(registro.user))

    feedback.completar!(
      diagnostico: resultado[:diagnostico],
      analisis: resultado[:analisis],
      accion_recomendada: resultado[:accion_recomendada],
      modelo: resultado[:modelo]
    )
  rescue StandardError => error
    feedback&.fallar!(error.message)
  end

  private
    def series_recientes(user)
      DetalleEntrenamiento.joins(:registro_entrenamiento, :ejercicio)
                          .where(registro_entrenamiento: { user_id: user.id })
                          .order(created_at: :desc).limit(SERIES_A_ANALIZAR)
                          .includes(:ejercicio, :registro_entrenamiento)
                          .map do |detalle|
        { ejercicio: detalle.ejercicio.nombre, fecha: detalle.registro_entrenamiento.fecha.iso8601,
          serie: detalle.serie, repeticiones: detalle.repeticiones,
          peso_kg: detalle.peso_kg, rpe: detalle.rpe }
      end
    end
end
