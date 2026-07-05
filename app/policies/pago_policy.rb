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

  # Historial financiero inmutable (SDD §08)
  def update?
    false
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? scope.all : scope.joins(:membresia).where(membresias: { user_id: user.id })
    end
  end
end
