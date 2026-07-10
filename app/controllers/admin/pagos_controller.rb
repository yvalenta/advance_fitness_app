class Admin::PagosController < ApplicationController
  def index
    authorize Pago
    @pagos = policy_scope(Pago).includes(:anulado_por, membresia: :user).order(fecha_pago: :desc, id: :desc)
  end

  def edit
    @pago = Pago.find(params[:id])
    authorize @pago
  end

  # Corrección de un pago vigente (Fase 5.11): solo monto y método
  def update
    @pago = Pago.find(params[:id])
    authorize @pago

    if @pago.update(params.expect(pago: %i[monto metodo]))
      redirect_to admin_pagos_path, notice: "Pago corregido."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # "Eliminar" = anular: el pago queda en el historial marcado como eliminado
  def destroy
    @pago = Pago.find(params[:id])
    authorize @pago
    @pago.anular!(por: Current.user)
    redirect_to admin_pagos_path, notice: "Pago marcado como eliminado."
  end
end
