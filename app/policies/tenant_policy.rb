# frozen_string_literal: true

# Solo superadmin gestiona tenants (SDD §16.6). No hay Scope: superadmin ve
# todos, otros roles no llegan a esta policy.
class TenantPolicy < ApplicationPolicy
  def index? = user.superadmin?
  def show? = user.superadmin?
  def create? = user.superadmin?
  def update? = user.superadmin?
  def destroy? = false

  # Panel Admin → Funcionalidades (Fase 18d): el admin del tenant enciende y
  # apaga features de SU tenant; nada más de la gestión de tenants se abre.
  def funcionalidades? = user.admin? && user.tenant_id == record.id
end
