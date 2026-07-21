# frozen_string_literal: true

class MembresiaPolicy < ApplicationPolicy
  def index?
    user.staff?
  end

  def show?
    propia? || user.staff?
  end

  def create?
    user.staff?
  end

  def update?
    user.staff?
  end

  # Renovar = pago + extensión del vencimiento (solo admin registra pagos)
  def renovar?
    user.admin?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end

  private
    def propia?
      record.user_id == user.id
    end
end
