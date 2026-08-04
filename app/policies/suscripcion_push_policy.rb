# frozen_string_literal: true

# Solo-dueño, sin rama de staff (mismo principio que CicloMenstrualPolicy):
# los dispositivos de un miembro no son asunto del staff — no hay vista que
# los liste y el Scope devuelve vacío para cualquier otra persona.
class SuscripcionPushPolicy < ApplicationPolicy
  def create? = propia?
  def destroy? = propia?

  class Scope < ApplicationPolicy::Scope
    # Deliberadamente SIN `del_tenant` y SIN rama de staff: aislamiento por
    # PERSONA, no por tenant.
    def resolve = scope.where(user_id: user.id)
  end

  private
    def propia? = record.user_id == user.id
end
