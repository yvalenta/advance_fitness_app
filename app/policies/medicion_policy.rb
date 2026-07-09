# Las mediciones las toma el staff (antropometría de suscripción) o el propio
# miembro (auto-registro de peso, Fase 5.9). Un miembro solo crea las suyas.
class MedicionPolicy < ApplicationPolicy
  def index? = user.staff?
  def new? = user.staff?

  def create?
    user.staff? || (record.respond_to?(:user_id) && record.user_id == user.id)
  end
end
