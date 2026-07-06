class RegistroCaloriaPolicy < ApplicationPolicy
  # El registro diario es siempre del propio miembro
  def create?
    user.present?
  end
end
