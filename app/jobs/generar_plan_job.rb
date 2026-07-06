# Genera con IA el plan personalizado de un miembro premium (SDD flujo B).
# Corre en Solid Queue: el request nunca espera a Claude. Revalida la
# suscripción EN LA BASE (no confía en el request) antes de llamar a la API.
class GenerarPlanJob < ApplicationJob
  queue_as :default

  retry_on Timeout::Error, wait: :polynomially_longer, attempts: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.premium?
    return if user.planes_personalizados.borradores.exists? # ya hay uno en revisión

    objetivo = user.objetivo_activo
    resultado = GeneradorPlanIa.generar(
      edad: user.edad,
      sexo: user.sexo,
      talla_cm: user.talla_cm.to_f,
      peso_kg: objetivo&.peso_kg.to_f,
      somatotipo: user.somatotipo,
      nivel_actividad: user.nivel_actividad.to_f,
      meta: objetivo&.nombre || "no definida",
      objetivo_kcal: objetivo&.objetivo_kcal,
      tdee_kcal: objetivo&.tdee_kcal
    )

    user.planes_personalizados.create!(
      rutina: resultado[:rutina],
      plan_nutricional: resultado[:plan_nutricional],
      generado_por: "ia",
      estado: "borrador"
    )
  end
end
