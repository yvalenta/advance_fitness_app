# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  # La pertenencia del RECORD sale del puesto (tarea 2026-08-31): staff y
  # mostrador ven/editan solo cuentas CON PUESTO en su gimnasio. Antes estas
  # dos reglas no miraban el tenant del record — un `User.find(id)` +
  # authorize dejaba a un admin ver y editar cuentas de otro tenant por ID;
  # con puestos el chequeo de pertenencia por fin tiene una sola verdad que
  # consultar y el hueco se cierra acá.
  def show?
    propio? || ((user.staff? || user.mostrador?) && del_gimnasio_del_staff?)
  end

  # Datos básicos editables desde el dashboard del admin (Fase 6.13): staff
  # (entrenador o admin) y mostrador (recepción o admin) — no solo admin. El
  # rol en sí se restringe aparte, en el controller, exclusivamente a
  # Current.user.admin?, así que recepción corrige un nombre o un correo mal
  # tecleado pero NO asciende a nadie ni se asciende a sí misma.
  def update?
    propio? || ((user.staff? || user.mostrador?) && del_gimnasio_del_staff?)
  end

  # Dar de alta al miembro en el mostrador (Flujo A del SDD).
  def create?
    user.mostrador?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Staff y mostrador enumeran por PUESTOS del tenant, no por la cache
      # users.tenant_id (tarea 2026-08-31): un miembro con puesto acá pero
      # ESTACIONADO en otro gimnasio seguiría existiendo para este — con la
      # cache sería invisible (e inextirpable: nadie podría encontrarlo para
      # quitarle el puesto), el bug exacto de nomicheck. El único de
      # (user_id, tenant_id) garantiza que el join no duplica filas. Miembro
      # solo se ve a sí mismo.
      if user.staff? || user.mostrador?
        scope.joins(:puestos).where(puestos: { tenant_id: user.tenant_id })
      else
        scope.where(id: user.id)
      end
    end
  end

  private
    def propio?
      record.id == user.id
    end

    # El staff opera sobre su tenant estacionado (`verificar_pertenencia_al_
    # tenant` garantiza cache == subdominio); el record pertenece si tiene
    # puesto ahí, esté estacionado donde esté.
    def del_gimnasio_del_staff?
      record.is_a?(User) && record.puestos.exists?(tenant_id: user.tenant_id)
    end
end
