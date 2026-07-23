# Registro cuantitativo de series: solo el dueño del entrenamiento, y solo
# si tiene suscripción activa al plan Personalizado (SDD §17 — feature
# premium, el plan free se queda con el checkbox "hecho" existente).
class DetalleEntrenamientoPolicy < ApplicationPolicy
  def index? = registro_del_usuario?
  def create? = registro_del_usuario? && user.premium?
  def destroy? = registro_del_usuario?
  # Fase 12: solo staff dispara el Analista de Performance (el miembro solo
  # ve el resultado) — el registro puede ser de cualquier miembro, no
  # necesariamente del propio staff que lo analiza.
  def analizar? = user.staff?

  class Scope < ApplicationPolicy::Scope
    # Aislado vía registro_entrenamiento → user → tenant.
    def resolve
      if user.staff?
        scope.joins(registro_entrenamiento: :user).where(users: { tenant_id: user.tenant_id })
      else
        scope.joins(:registro_entrenamiento).where(registro_entrenamientos: { user_id: user.id })
      end
    end
  end

  private
    def registro_del_usuario?
      registro = record.is_a?(RegistroEntrenamiento) ? record : record.registro_entrenamiento
      registro.user_id == user.id
    end
end
