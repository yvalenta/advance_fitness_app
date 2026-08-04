# El catálogo de ejercicios (ayudas visuales e instrucciones) es de consulta
# para cualquier usuario autenticado — al miembro le sirve en su rutina y en
# el explorador del catálogo (Fase 14.5), al staff en el editor (SDD Fase 6).
# El catálogo es GLOBAL por diseño (SDD §16.6): sin aislamiento por tenant.
class EjercicioPolicy < ApplicationPolicy
  def index? = user.present?
  def ayuda? = user.present?
  def media? = user.present?
end
