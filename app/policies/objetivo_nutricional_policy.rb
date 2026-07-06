class ObjetivoNutricionalPolicy < ApplicationPolicy
  # Cada miembro gestiona únicamente su propio objetivo; los controllers
  # construyen siempre desde Current.user, la policy lo garantiza.
  def show?
    propio?
  end

  def create?
    user.present?
  end

  private

  def propio?
    record.is_a?(Class) ? user.present? : record.user_id == user.id
  end
end
