# frozen_string_literal: true

# Solo superadmin gestiona tenants (SDD §16.6). No hay Scope: superadmin ve
# todos, otros roles no llegan a esta policy.
class TenantPolicy < ApplicationPolicy
  def index? = user.superadmin?
  def show? = user.superadmin?
  def create? = user.superadmin?
  def update? = user.superadmin?
  def destroy? = false
end
