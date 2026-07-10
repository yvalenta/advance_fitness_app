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

  # Editor de plan (SDD Fase 5.6): el entrenador edita antes de publicar y el
  # admin también después, desde Suscripciones. Desde la Fase 5.11 el miembro
  # edita su PROPIO plan sugerido (reglas); los de IA siguen siendo del staff.
  def editar?
    user.staff? || (record.user_id == user.id && record.reglas?)
  end

  def publicar? = revisar?
end
