# Registro cuantitativo de series: solo el dueño del entrenamiento, y solo
# si tiene suscripción activa al plan Personalizado (SDD §17 — feature
# premium, el plan free se queda con el checkbox "hecho" existente).
class DetalleEntrenamientoPolicy < ApplicationPolicy
  def index? = registro_del_usuario?
  def create? = registro_del_usuario? && user.premium?
  def destroy? = registro_del_usuario?
  # Fase 12: solo staff dispara el Analista de Performance (el miembro solo
  # ve el resultado) — el registro puede ser de cualquier miembro DE SU
  # GIMNASIO, no necesariamente del propio staff que lo analiza.
  def analizar? = user.staff? && duenio_del_gimnasio_del_staff?

  class Scope < ApplicationPolicy::Scope
    # Aislado vía registro_entrenamiento → user → PUESTO (tarea 2026-08-31):
    # antes el join terminaba en `users.tenant_id` (la cache) y las series de
    # un miembro estacionado en otro gimnasio se esfumaban de las listas del
    # staff de acá. El único de (user_id, tenant_id) evita duplicados.
    def resolve
      if user.staff?
        scope.joins(registro_entrenamiento: { user: :puestos })
             .where(puestos: { tenant_id: user.tenant_id })
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

    # Defensa en profundidad (tarea 2026-08-31, patrón de MedicionPolicy):
    # además del rol, el DUEÑO del registro debe tener puesto en el gimnasio
    # del staff. El controller de analizar ya carga por policy_scope, pero si
    # mañana uno descuidado vuelve al find crudo, esta capa lo frena sola.
    def duenio_del_gimnasio_del_staff?
      registro = record.is_a?(RegistroEntrenamiento) ? record : record.registro_entrenamiento
      registro.user.present? && registro.user.puestos.exists?(tenant_id: user.tenant_id)
    end
end
