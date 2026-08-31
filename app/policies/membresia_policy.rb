# frozen_string_literal: true

class MembresiaPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    propia? || user.staff? || user.mostrador?
  end

  def create?
    user.staff? || user.mostrador?
  end

  def update?
    user.staff? || user.mostrador?
  end

  # Renovar = pago + extensión del vencimiento. Va con quien cobra: admin y
  # recepción (antes solo admin, porque `recepcion` no existía y el único que
  # registraba pagos era él).
  def renovar?
    user.mostrador?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.staff? || user.mostrador?
        del_tenant_directo(scope)
      else
        scope.where(user_id: user.id)
      end
    end
  end

  private
    def propia?
      record.user_id == user.id
    end
end
