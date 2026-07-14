# Autocuración de la cola (mismo patrón de LiberarPlanesEstancadosJob): si un
# worker muere a mitad de un AnalizarEntrenamientoJob, el feedback queda en
# "generando" para siempre. Este job corre cada pocos minutos y lo marca
# "fallido" con un mensaje claro, para que el miembro pueda reintentar.
class LiberarFeedbacksEstancadosJob < ApplicationJob
  queue_as :default

  def perform
    FeedbackIa.estancados.find_each do |feedback|
      feedback.fallar!("El análisis se interrumpió (el proceso se reinició a mitad de camino). Reintenta.")
    end
  end
end
