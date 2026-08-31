# frozen_string_literal: true

class AccesoPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    record.user_id == user.id ||
      ((user.staff? || user.mostrador?) && duenio_del_gimnasio_del_staff?)
  end

  # Staff y mostrador registran check-ins; el propio miembro puede
  # auto-registrarse. El check-in es LA tarea de recepción (Flujo D del SDD).
  def create?
    record.user_id == user.id ||
      ((user.staff? || user.mostrador?) && duenio_del_gimnasio_del_staff?)
  end

  def update?
    false
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.staff? || user.mostrador?
        del_tenant(scope)
      else
        scope.where(user_id: user.id)
      end
    end
  end

  private
    # Defensa en profundidad (tarea 2026-08-31, patrón de UserPolicy#del_
    # gimnasio_del_staff?): el miembro al que se le registra o muestra el
    # acceso debe tener puesto en el gimnasio del viewer. El controller ya
    # carga al miembro vía policy_scope; esta capa evita que un tercer
    # controller con un find crudo reabra el hueco mañana.
    def duenio_del_gimnasio_del_staff?
      return true unless record.is_a?(Acceso)
      record.user.present? && record.user.puestos.exists?(tenant_id: user.tenant_id)
    end
end
