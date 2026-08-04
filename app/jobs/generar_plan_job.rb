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
      medicion: medicion,
      # Fase 6.5/6.6: catálogo cerrado de ejercicios + adherencia real.
      # Etapa 14.10: al regenerar viaja también la posición en el mesociclo
      # del plan vigente ("Va en la semana 3 de 4…") y la adherencia por
      # semana del ciclo (contexto_ciclo / por_semana dentro del resumen).
      catalogo: Ejercicios::CatalogoParaPrompt.para,
      adherencia: ResumenAdherencia.para(plan.user, plan: plan.user.plan_aprobado),
      # Fase 14.16: la fase del ciclo viaja al proveedor de IA SOLO con el
      # consentimiento de segundo nivel (ciclo_menstrual_ia — distinto del de
      # registro; el texto que la miembro aceptó nombra al proveedor externo).
      # El job decide, no el PORO: GeneradorPlanIa recibe el dato ya filtrado.
      ciclo: fase_ciclo_consentida(plan.user)
    )

    # Anti-alucinación (Fase 6.5): ids inexistentes se rescatan o se limpian
    validacion = Ejercicios::ValidadorRutina.corregir!(resultado[:rutina])
    if validacion[:correcciones].positive?
      Rails.logger.info("GenerarPlanJob: #{validacion[:correcciones]} correcciones de catálogo en el plan #{plan.id}")
    end

    plan.completar!(
      rutina: validacion[:rutina],
      plan_nutricional: resultado[:plan_nutricional],
      modelo: resultado[:modelo]
    )
  rescue StandardError => error
    # Sin conexión no hay cómo persistir el fallo — se re-lanza para que el
    # retry_on de ApplicationJob lo reintente pasada la ventana de deploy.
    raise if error.is_a?(ActiveRecord::ConnectionNotEstablished)
    plan&.fallar!(error.message)
  end

  private

    # nil sin consentimiento de IA o sin datos (:desconocida) — el bloque del
    # prompt simplemente no existe. El prompt no se persiste ni se loguea.
    def fase_ciclo_consentida(user)
      return unless Consentimiento.vigente?(user, "ciclo_menstrual_ia")

      fase = Ciclo::Fase.para(user)
      fase == :desconocida ? nil : fase.to_s
    end
end
