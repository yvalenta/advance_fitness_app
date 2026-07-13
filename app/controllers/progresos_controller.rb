class ProgresosController < ApplicationController
  def show
    authorize :progreso, :show?
    @progreso = ProgresoUsuario.para(Current.user)
  end
end
