# frozen_string_literal: true

class AccesoPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    record.user_id == user.id || user.staff? || user.mostrador?
  end

  # Staff y mostrador registran check-ins; el propio miembro puede
  # auto-registrarse. El check-in es LA tarea de recepción (Flujo D del SDD).
  def create?
    user.staff? || user.mostrador? || record.user_id == user.id
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
end
