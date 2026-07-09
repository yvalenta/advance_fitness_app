# Genera con IA el plan personalizado de un miembro premium (SDD flujo B).
# Corre en Solid Queue: el request nunca espera a la IA. Opera sobre un plan
# ya creado en estado "generando"; revalida la suscripción EN LA BASE antes de
# llamar a la API. Los fallos NO se re-lanzan: quedan como estado "fallido" con
# su mensaje, para que el staff los vea y reintente (SDD Fase 5.7).
class GenerarPlanJob < ApplicationJob
  queue_as :default

  def perform(plan_id)
    plan = PlanPersonalizado.find_by(id: plan_id)
    return unless plan

    unless plan.user.premium?
      return plan.fallar!("Sin suscripción personalizada activa")
    end

    plan.marcar_generando!
    objetivo = plan.user.objetivo_activo
    medicion = plan.user.ultima_medicion
    resultado = GeneradorPlanIa.generar(
      edad: plan.user.edad,
      sexo: plan.user.sexo,
      talla_cm: plan.user.talla_cm.to_f,
      peso_kg: (medicion&.peso_kg || objetivo&.peso_kg).to_f,
      somatotipo: plan.user.somatotipo,
      nivel_actividad: plan.user.nivel_actividad.to_f,
      meta: objetivo&.nombre || "no definida",
      objetivo_kcal: objetivo&.objetivo_kcal,
      tdee_kcal: objetivo&.tdee_kcal,
      medicion: medicion
    )

    plan.completar!(
      rutina: resultado[:rutina],
      plan_nutricional: resultado[:plan_nutricional],
      modelo: resultado[:modelo]
    )
  rescue StandardError => error
    plan&.fallar!(error.message)
  end
end
