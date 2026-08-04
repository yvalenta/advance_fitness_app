# frozen_string_literal: true

# Logros conseguidos (Fase 14.12): los otorga el motor, no la UI — por eso
# ni el staff crea filas a mano. Se consultan como los accesos: el miembro
# ve los suyos, el staff los de su tenant.
class LogroObtenidoPolicy < ApplicationPolicy
  def index? = true
  def show? = record.user_id == user.id || user.staff?
  def create? = false
  def update? = false
  def destroy? = false

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
