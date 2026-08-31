# Las mediciones las toma el staff (antropometría de suscripción) o el propio
# miembro (auto-registro de peso, Fase 5.9). Un miembro solo crea las suyas.
# `user.mostrador?` NO va acá (Fase 18k): la antropometría es el cuerpo de la
# persona, no el mostrador — recepción cobra, da acceso y da de alta, y estas
# medidas quedan entre el miembro y su entrenador.
class MedicionPolicy < ApplicationPolicy
  def index? = user.staff?
  def new? = user.staff? && duenio_del_gimnasio_del_staff?
  # Edición de mediciones pasadas (Fase 6.11): solo el staff, nunca el miembro.
  def edit? = user.staff? && duenio_del_gimnasio_del_staff?
  def update? = user.staff? && duenio_del_gimnasio_del_staff?

  def create?
    (user.staff? && duenio_del_gimnasio_del_staff?) ||
      (record.respond_to?(:user_id) && record.user_id == user.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end

  private
    # Defensa en profundidad (tarea 2026-08-31, patrón de UserPolicy#del_
    # gimnasio_del_staff?): además del rol, el DUEÑO de la medición debe
    # tener puesto en el gimnasio del staff. El controller ya carga al
    # miembro vía policy_scope, pero si mañana un controller descuidado
    # vuelve al find crudo, esta capa lo frena sola. Con la CLASE (authorize
    # Medicion en #index) no hay dueño que mirar: decide solo el rol.
    def duenio_del_gimnasio_del_staff?
      return true unless record.is_a?(Medicion)
      record.user.present? && record.user.puestos.exists?(tenant_id: user.tenant_id)
    end
end
