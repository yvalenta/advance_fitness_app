# frozen_string_literal: true

# La ÚNICA policy del repo donde el staff NO ve nada (Fase 14.15). El ciclo
# menstrual es un dato de salud sensible entre la usuaria y la app: ni el
# admin ni el entrenador de su propio tenant lo listan, leen ni tocan. No
# hay vista de staff que lo muestre, y el Scope tampoco tiene rama de staff
# — si alguien la agrega, fallan a propósito los specs de blindaje
# (spec/policies/ciclo_menstrual_policy_spec.rb y el ejemplo de
# spec/policies/aislamiento_cross_tenant_spec.rb).
class CicloMenstrualPolicy < ApplicationPolicy
  def index? = true
  def show? = propia?
  # Crear exige, además de ser propio, consentimiento vigente: sin la fila
  # `ciclo_menstrual` otorgada (Fase 14.11) no se captura ni un dato.
  def create? = propia? && Consentimiento.vigente?(user, "ciclo_menstrual")
  def update? = false
  # Borrar lo propio NO exige consentimiento vigente: retirar sus datos es
  # un derecho que no depende de haber consentido nada.
  def destroy? = propia?

  class Scope < ApplicationPolicy::Scope
    # Deliberadamente SIN `del_tenant` y SIN rama de staff: el aislamiento
    # aquí no es por tenant sino por PERSONA. El staff obtiene un scope
    # vacío aunque existan ciclos en su tenant — `user.staff?` jamás debe
    # aparecer en este método (dato de salud sensible, SDD §16.6 no aplica).
    def resolve = scope.where(user_id: user.id)
  end

  private
    def propia? = record.user_id == user.id
end
