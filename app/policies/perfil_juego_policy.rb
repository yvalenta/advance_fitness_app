# frozen_string_literal: true

# Proyección del motor de juego (Fase 14.12). El scope filtra DIRECTO por
# `tenant_id` (del_tenant_directo, sin join): es la base del futuro
# leaderboard, también para miembros. `update?` es SOLO del propio miembro —
# el staff JAMÁS activa `visible_en_tabla` por él (aparecer en la tabla exige
# además consentimiento `tabla_posiciones` vigente, Fase 14.11).
class PerfilJuegoPolicy < ApplicationPolicy
  def index? = true
  def show? = record.user_id == user.id || user.staff?
  def create? = false # los perfiles los crea el motor (PerfilJuego.para)
  def update? = record.user_id == user.id
  def destroy? = false

  class Scope < ApplicationPolicy::Scope
    def resolve = del_tenant_directo(scope)
  end
end
