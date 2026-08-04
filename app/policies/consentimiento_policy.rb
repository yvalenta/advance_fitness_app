# frozen_string_literal: true

# Los consentimientos son estrictamente personales (Fase 14.11): solo el
# propio usuario crea y lee los suyos. NADIE — ni el staff — lee los de
# otros, y nadie edita ni borra (append-only, mismo espíritu que `pagos`).
class ConsentimientoPolicy < ApplicationPolicy
  def index? = true
  def show? = record.user_id == user.id
  def create? = record.user_id == user.id
  def update? = false
  def destroy? = false

  # A diferencia del resto de scopes, el staff NO recibe `del_tenant`:
  # el consentimiento es un dato del usuario consigo mismo.
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(user_id: user.id)
  end
end
