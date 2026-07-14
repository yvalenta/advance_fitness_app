# Registro cuantitativo de series: solo el dueño del entrenamiento, y solo
# si tiene suscripción activa al plan Personalizado (SDD §17 — feature
# premium, el plan free se queda con el checkbox "hecho" existente).
class DetalleEntrenamientoPolicy < ApplicationPolicy
  def index? = registro_del_usuario?
  def create? = registro_del_usuario? && user.premium?
  def destroy? = registro_del_usuario?

  private
    def registro_del_usuario?
      registro = record.is_a?(RegistroEntrenamiento) ? record : record.registro_entrenamiento
      registro.user_id == user.id
    end
end
