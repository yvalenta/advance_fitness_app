# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user.staff? || user.mostrador?
  end

  def show?
    propio? || user.staff? || user.mostrador?
  end

  # Datos básicos editables desde el dashboard del admin (Fase 6.13): staff
  # (entrenador o admin) y mostrador (recepción o admin) — no solo admin. El
  # rol en sí se restringe aparte, en el controller, exclusivamente a
  # Current.user.admin?, así que recepción corrige un nombre o un correo mal
  # tecleado pero NO asciende a nadie ni se asciende a sí misma.
  def update?
    propio? || user.staff? || user.mostrador?
  end

  # Dar de alta al miembro en el mostrador (Flujo A del SDD).
  def create?
    user.mostrador?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Staff y mostrador ven solo users de su tenant (SDD §16.6); miembro
      # solo se ve a sí mismo.
      if user.staff? || user.mostrador?
        scope.where(tenant_id: user.tenant_id)
      else
        scope.where(id: user.id)
      end
    end
  end

  private
    def propio?
      record.id == user.id
    end
end
