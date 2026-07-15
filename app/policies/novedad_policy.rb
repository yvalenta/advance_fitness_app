class NovedadPolicy < ApplicationPolicy
  def index? = true
  def admin_index? = user.staff?
  def create? = user.staff?
  def update? = user.staff?
  def destroy? = user.staff?
end
