class Admin::PagosController < ApplicationController
  def index
    authorize Pago
    @q = params[:q].to_s.strip
    @pagos = policy_scope(Pago).includes(:anulado_por, membresia: :user).order(fecha_pago: :desc, id: :desc)
    @pagos = filtrar(@pagos, @q) if @q.present?
    @pagos = @pagos.page(params[:page]).per(25)
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

  private
    # Un solo campo de búsqueda (Fase 6.13) que interpreta lo que se escribió:
    # método (efectivo/transferencia/tarjeta), valor (solo dígitos), fecha
    # (con separador de fecha) o, si no calza con nada de eso, el miembro.
    def filtrar(scope, q)
      metodo = Pago::METODOS.find { |m| m.start_with?(q.downcase) }
      return scope.where(metodo: metodo) if metodo

      return scope.where("monto::text LIKE :q", q: "%#{q.delete(".,")}%") if q.match?(/\A[\d.,]+\z/)

      if q.match?(%r{[/-]}) && (fecha = Date.parse(q) rescue nil)
        return scope.where(fecha_pago: fecha)
      end

      scope.joins(membresia: :user)
           .where("users.nombre ILIKE :q OR users.email_address ILIKE :q", q: "%#{User.sanitize_sql_like(q)}%")
    end
end
