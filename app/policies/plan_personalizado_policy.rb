class PlanPersonalizadoPolicy < ApplicationPolicy
  # El miembro solo ve su propio plan y solo si está aprobado (SDD §07);
  # el staff puede ver cualquiera DE SU GIMNASIO (el entrenador revisa
  # borradores — el dueño del plan debe tener puesto en su tenant).
  def show?
    return duenio_del_gimnasio_del_staff? if user.staff?

    record.user_id == user.id && record.aprobado?
  end

  # Revisión y aprobación: entrenador (o admin), sobre planes de su gimnasio
  def revisar? = (user.entrenador? || user.admin?) && duenio_del_gimnasio_del_staff?
  def aprobar? = revisar?

  # NUTRICIÓN por comida (SDD Fase 5.6, ampliado Fase 12.1): el entrenador
  # edita antes de publicar y el admin también después, desde Suscripciones.
  # El miembro edita la nutrición de CUALQUIERA de sus planes publicados
  # (sugerido o de IA) para acomodarla a su gusto y llegar a su objetivo
  # diario — mismo criterio que ya rige la rutina desde la Fase 5.12.
  def editar?
    (user.staff? && duenio_del_gimnasio_del_staff?) ||
      (record.user_id == user.id && record.aprobado?)
  end

  # RUTINA (días/ejercicios): desde la Fase 5.12 el miembro edita la rutina de
  # CUALQUIERA de sus planes publicados (sugerido o de IA) — músculos del día,
  # ejercicios y sesiones.
  def editar_rutina?
    (user.staff? && duenio_del_gimnasio_del_staff?) ||
      (record.user_id == user.id && record.aprobado?)
  end

  # Editor JSON crudo ("modo avanzado"): solo staff — permite reescribir
  # rutina y nutrición de un tirón sin las validaciones por campo del
  # autosave, demasiado riesgoso para exponerlo al propio miembro.
  def editar_json? = user.staff? && duenio_del_gimnasio_del_staff?

  def publicar? = revisar?

  class Scope < ApplicationPolicy::Scope
    # `aprobado` NO es una columna: el estado vive en `estado` y `aprobado?`
    # es un predicado del modelo (ESTADOS = generando/borrador/aprobado/
    # fallido). La rama del no-staff pedía `aprobado: true` y reventaba con
    # PG::UndefinedColumn — nunca se notó porque hoy ningún controller llama
    # a `policy_scope(PlanPersonalizado)` y los specs solo ejercitaban la
    # rama de staff. Lo caza el spec de blindaje de recepción (Fase 18k),
    # que es el primer rol no-staff que pasa por acá.
    def resolve
      user.staff? ? del_tenant(scope) : scope.aprobados.where(user_id: user.id)
    end
  end

  private
    # Defensa en profundidad (tarea 2026-08-31, patrón de MedicionPolicy):
    # además del rol, el DUEÑO del plan debe tener puesto en el gimnasio del
    # staff. Los controllers del editor ya cargan por policy_scope, pero si
    # mañana uno descuidado vuelve al find crudo, esta capa lo frena sola.
    # Con la CLASE (authorize PlanPersonalizado, :revisar? en la cola de
    # borradores) no hay dueño que mirar: decide solo el rol.
    def duenio_del_gimnasio_del_staff?
      return true unless record.is_a?(PlanPersonalizado)
      record.user.present? && record.user.puestos.exists?(tenant_id: user.tenant_id)
    end
end
