class SuscripcionPolicy < ApplicationPolicy
  # Solo el admin registra la compra en recepción (SDD §08, flujo B)
  def index? = user.admin?
  def create? = user.admin?
  def update? = user.admin?
end
