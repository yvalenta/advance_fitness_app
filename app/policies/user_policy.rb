# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user.staff?
  end

  def show?
    propio? || user.staff?
  end

  # Datos básicos editables desde el dashboard del admin (Fase 6.13): staff
  # (entrenador o admin), no solo admin — el rol en sí se restringe aparte,
  # en el controller, exclusivamente a Current.user.admin?.
  def update?
    propio? || user.staff?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Staff ve solo miembros de su tenant (SDD §16.6); miembro solo se ve
      # a sí mismo.
      if user.staff?
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
