# frozen_string_literal: true

class PagoPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    record.membresia.user_id == user.id ||
      ((user.staff? || user.mostrador?) && del_gimnasio_del_staff?)
  end

  # Cobrar es el oficio del mostrador (Fase 18k): admin y recepción registran
  # el pago. Antes era solo admin, lo que obligaba al dueño del gimnasio a
  # estar presente para cada cuota.
  def create?
    user.mostrador?
  end

  # Historial financiero auditable (SDD §08, Fase 5.11): el admin corrige un
  # pago vigente o lo anula (figura como eliminado); nunca se borra físico.
  # Recepción NO corrige ni anula: quien cobra no borra su propio rastro —
  # un error de mostrador lo arregla el admin, y queda quién lo hizo.
  def update?
    user.admin? && !record.anulado? && del_gimnasio_del_staff?
  end

  def destroy?
    user.admin? && !record.anulado? && del_gimnasio_del_staff?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.staff? || user.mostrador?
        # `tenant_id` propio (SDD §16.7): antes eran dos joins hasta `users`.
        del_tenant_directo(scope)
      else
        scope.joins(:membresia).where(membresias: { user_id: user.id })
      end
    end
  end

  private
    # Defensa en profundidad (tarea 2026-08-31): además del rol, el pago debe
    # anclar en el gimnasio del viewer por su `tenant_id` desnormalizado
    # (SDD §16.7) — un find crudo en un controller descuidado ya no basta
    # para corregir o anular dinero del gimnasio vecino.
    def del_gimnasio_del_staff?
      return true unless record.is_a?(Pago)
      record.tenant_id == user.tenant_id
    end
end
