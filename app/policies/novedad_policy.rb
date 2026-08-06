class NovedadPolicy < ApplicationPolicy
  def index? = true
  # Opt-in del muro (Fase 18e): decisión personal de un miembro de tenant —
  # superadmin/comercializador no tienen logros que compartir.
  def participar? = !user.global?
  def admin_index? = user.staff?
  def create? = user.staff?
  def update? = user.staff?
  def destroy? = user.staff?

  # `novedades` tiene tenant_id directo (SDD §16.6). Aislado por columna, no por join.
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(tenant_id: user.tenant_id)
  end
end
