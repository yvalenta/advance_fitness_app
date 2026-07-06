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
end
