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

  # NUTRICIÓN por comida (SDD Fase 5.6, ampliado Fase 12.1): el entrenador
  # edita antes de publicar y el admin también después, desde Suscripciones.
  # El miembro edita la nutrición de CUALQUIERA de sus planes publicados
  # (sugerido o de IA) para acomodarla a su gusto y llegar a su objetivo
  # diario — mismo criterio que ya rige la rutina desde la Fase 5.12.
  def editar?
    user.staff? || (record.user_id == user.id && record.aprobado?)
  end

  # RUTINA (días/ejercicios): desde la Fase 5.12 el miembro edita la rutina de
  # CUALQUIERA de sus planes publicados (sugerido o de IA) — músculos del día,
  # ejercicios y sesiones.
  def editar_rutina?
    user.staff? || (record.user_id == user.id && record.aprobado?)
  end

  # Editor JSON crudo ("modo avanzado"): solo staff — permite reescribir
  # rutina y nutrición de un tirón sin las validaciones por campo del
  # autosave, demasiado riesgoso para exponerlo al propio miembro.
  def editar_json? = user.staff?

  def publicar? = revisar?
end
