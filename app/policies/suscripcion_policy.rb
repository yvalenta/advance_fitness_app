class SuscripcionPolicy < ApplicationPolicy
  # Solo el admin registra la compra en recepción (SDD §08, flujo B)
  def index? = user.admin?
  def create? = user.admin?
  # Defensa en profundidad (tarea 2026-08-31): cancelar o cambiar el tier
  # exige además que la fila ancle en el gimnasio del admin (`tenant_id`
  # desnormalizado, SDD §16.7) — con la CLASE decide solo el rol.
  def update? = user.admin? && del_gimnasio_del_staff?

  # Red de seguridad de aislamiento cross-tenant (SDD §16.6, Etapa 1 del plan
  # de estabilización): el staff jamás debe listar suscripciones de otro tenant.
  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant_directo(scope) : scope.where(user_id: user.id)
    end
  end

  private
    def del_gimnasio_del_staff?
      return true unless record.is_a?(Suscripcion)
      record.tenant_id == user.tenant_id
    end
end
