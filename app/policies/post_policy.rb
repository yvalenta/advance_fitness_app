class PostPolicy < ApplicationPolicy
  def index? = true
  def admin_index? = user.staff?
  def show? = record.publicado? || user.staff?
  def create? = user.staff?
  def update? = user.staff?
  def destroy? = user.staff?
  def publicar? = user.staff?

  # `posts` tiene tenant_id directo (SDD §16.6). Aislado por columna, no por join.
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(tenant_id: user.tenant_id)
  end
end
