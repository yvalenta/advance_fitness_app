class NovedadesController < ApplicationController
  def index
    authorize Novedad
    @novedades = Novedad.publicadas
  end
end
