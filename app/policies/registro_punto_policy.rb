# frozen_string_literal: true

# Ledger de puntos (Fase 14.12): lo escribe el motor (Juego::Otorgador vía
# OtorgarPuntosJob), nunca la UI — salvo el futuro `ajuste_manual` del staff,
# que lleva `creado_por`. Append-only: nadie edita ni borra.
class RegistroPuntoPolicy < ApplicationPolicy
  def index? = true
  def show? = record.user_id == user.id || user.staff?
  def create? = user.staff? # solo ajuste_manual; el resto entra por jobs
  def update? = false
  def destroy? = false

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.staff? ? del_tenant(scope) : scope.where(user_id: user.id)
    end
  end
end
