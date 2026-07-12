class PlanPersonalizadoPolicy < ApplicationPolicy
  # El miembro solo ve su propio plan y solo si está aprobado (SDD §07);
  # el staff puede ver cualquiera (el entrenador revisa borradores).
  def show?
    return true if user.staff?

    record.user_id == user.id && record.aprobado?
  end

  # Revisión y aprobación: entrenador (o admin)
  def revisar? = user.entrenador? || user.admin?
  def aprobar? = revisar?

  # Editor completo (JSON crudo) y NUTRICIÓN (SDD Fase 5.6): el entrenador
  # edita antes de publicar y el admin también después, desde Suscripciones.
  # Desde la Fase 5.11 el miembro edita la nutrición de su PROPIO plan
  # sugerido (reglas, aunque nace vacía); la de un plan de IA sigue siendo
  # solo del staff.
  def editar?
    user.staff? || (record.user_id == user.id && record.reglas?)
  end

  # RUTINA (días/ejercicios): desde la Fase 5.12 el miembro edita la rutina de
  # CUALQUIERA de sus planes publicados (sugerido o de IA) — músculos del día,
  # ejercicios y sesiones. La nutrición del plan de IA sigue siendo del staff.
  def editar_rutina?
    user.staff? || (record.user_id == user.id && record.aprobado?)
  end

  def publicar? = revisar?
end
