# frozen_string_literal: true

class AccesoPolicy < ApplicationPolicy
  def index?
    user.staff?
  end

  def show?
    record.user_id == user.id || user.staff?
  end

  # Staff registra check-ins; el propio miembro puede auto-registrarse
  def create?
    user.staff? || record.user_id == user.id
  end

  def update?
    false
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
