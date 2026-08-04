# frozen_string_literal: true

# Catálogo de logros (Fase 14.12): `tenant_id` nil = catálogo GLOBAL visible
# para todos los tenants (a propósito — patrón de `Ejercicio`); con tenant =
# propio de ese gimnasio. El admin solo administra los de SU tenant: los
# globales no se tocan desde ningún tenant.
class LogroPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = user.admin?
  def update? = user.admin? && record.tenant_id == user.tenant_id
  def destroy? = user.admin? && record.tenant_id == user.tenant_id

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(tenant_id: [ nil, user.tenant_id ])
  end
end
