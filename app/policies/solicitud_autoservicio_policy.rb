# frozen_string_literal: true

# Cola de leads del autoservicio (§17.5): solo el staff del portal comercial
# la trabaja — superadmin y comercializador (§16.6). Sin Scope: es una
# colección global, no aislada por tenant (los leads no pertenecen a ninguno
# todavía).
class SolicitudAutoservicioPolicy < ApplicationPolicy
  def index? = staff_comercial?
  def update? = staff_comercial?

  private
    def staff_comercial? = user.superadmin? || user.comercializador?
end
