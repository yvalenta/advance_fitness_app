class PlanPolicy < ApplicationPolicy
  # El catálogo (pantalla de upgrade) es visible para cualquier autenticado
  def index?
    user.present?
  end
end
