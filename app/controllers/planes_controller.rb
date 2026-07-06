# Pantalla de upgrade: comparación Free vs. Personalizado (SDD flujo B paso 1)
class PlanesController < ApplicationController
  def index
    authorize Plan, :index?
    @planes = Plan.order(:precio)
    @suscripcion = Current.user.suscripcion_activa
  end
end
