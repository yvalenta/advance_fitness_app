class PostPolicy < ApplicationPolicy
  def index? = true
  def admin_index? = user.staff?
  def show? = record.publicado? || user.staff?
  def create? = user.staff?
  def update? = user.staff?
  def destroy? = user.staff?
  def publicar? = user.staff?
end
