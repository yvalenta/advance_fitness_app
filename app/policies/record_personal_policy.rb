# frozen_string_literal: true

# Récords personales (Fase 14.13): los escribe solo Juego::DetectorPr desde
# el registro de series, nunca la UI. Histórico puro: nadie edita ni borra —
# un PR superado se marca `superado_en` desde el detector, jamás a mano.
class RecordPersonalPolicy < ApplicationPolicy
  def index? = true
  def show? = record.user_id == user.id || user.staff?
  def create? = false # solo el detector
  def update? = false
  def destroy? = false

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
