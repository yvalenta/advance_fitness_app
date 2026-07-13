# Autocuración de la cola (Fase 6.14): si un worker muere a mitad de una
# generación con IA (p. ej. lo mata un deploy mientras corre GenerarPlanJob),
# el plan queda en "generando" para siempre sin que nada lo reintente. Este
# job corre cada pocos minutos y marca esos planes como "fallido" con un
# mensaje claro, para que aparezcan en la cola del entrenador con "Reintentar".
class LiberarPlanesEstancadosJob < ApplicationJob
  queue_as :default

  def perform
    PlanPersonalizado.estancados.find_each do |plan|
      plan.fallar!("La generación se interrumpió (el proceso se reinició a mitad de camino). Reintenta.")
    end
  end
end
