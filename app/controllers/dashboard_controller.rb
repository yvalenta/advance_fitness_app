class DashboardController < ApplicationController
  def show
    @membresia = Current.user.membresia
    @objetivo = Current.user.objetivo_activo
    @registro_hoy = Current.user.registros_calorias.find_by(fecha: Date.current)
  end
end
