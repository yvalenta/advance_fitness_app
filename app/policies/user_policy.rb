# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    propio? || user.staff?
  end

  def update?
    propio? || user.admin?
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
