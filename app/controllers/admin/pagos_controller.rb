class Admin::PagosController < ApplicationController
  def index
    authorize Pago
    @pagos = policy_scope(Pago).includes(membresia: :user).order(fecha_pago: :desc, id: :desc)
  end
end
