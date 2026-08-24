class ReprogramacionDiaPolicy < ApplicationPolicy
  def create? = propio?
  def destroy? = propio?

  private
    def propio? = record.plan_personalizado.user_id == user.id
end
