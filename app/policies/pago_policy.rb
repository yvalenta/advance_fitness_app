# frozen_string_literal: true

class PagoPolicy < ApplicationPolicy
  def index?
    user.staff?
  end

  def show?
    record.membresia.user_id == user.id || user.staff?
  end

  def create?
    user.admin?
  end

  # Historial financiero auditable (SDD §08, Fase 5.11): el admin corrige un
  # pago vigente o lo anula (figura como eliminado); nunca se borra físico.
  def update?
    user.admin? && !record.anulado?
  end

  def destroy?
    user.admin? && !record.anulado?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? scope.all : scope.joins(:membresia).where(membresias: { user_id: user.id })
    end
  end
end
