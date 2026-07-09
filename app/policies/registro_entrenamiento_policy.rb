# El miembro solo registra el seguimiento de su propio entrenamiento (Fase 5.10).
class RegistroEntrenamientoPolicy < ApplicationPolicy
  def create? = record.respond_to?(:user_id) && record.user_id == user.id
end
