# frozen_string_literal: true

class PagoPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    record.membresia.user_id == user.id || user.staff? || user.mostrador?
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
    user.admin? && !record.anulado?
  end

  def destroy?
    user.admin? && !record.anulado?
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
end
