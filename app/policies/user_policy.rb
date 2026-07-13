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
      user.staff? ? scope.all : scope.where(id: user.id)
    end
  end

  private
    def propio?
      record.id == user.id
    end
end
