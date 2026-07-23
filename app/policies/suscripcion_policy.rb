class SuscripcionPolicy < ApplicationPolicy
  # Solo el admin registra la compra en recepción (SDD §08, flujo B)
  def index? = user.admin?
  def create? = user.admin?
  def update? = user.admin?

  # Red de seguridad de aislamiento cross-tenant (SDD §16.6, Etapa 1 del plan
  # de estabilización): el staff jamás debe listar suscripciones de otro tenant.
  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
