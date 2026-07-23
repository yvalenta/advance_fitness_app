class RegistroCaloriaPolicy < ApplicationPolicy
  # El registro diario es siempre del propio miembro
  def create?
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
