# El catálogo de ejercicios (ayudas visuales e instrucciones) es de consulta
# para cualquier usuario autenticado: la ayuda de ejecución le sirve tanto al
# miembro en su rutina como al staff en el editor (SDD Fase 6).
class EjercicioPolicy < ApplicationPolicy
  def index? = user.present?
  def ayuda? = user.present?
  def media? = user.present?
end
