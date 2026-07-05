class Admin::RenovacionesController < ApplicationController
  def create
    membresia = Membresia.find(params[:membresia_id])
    authorize membresia, :renovar?

    membresia.renovar!(
      monto: params[:monto],
      metodo: params[:metodo],
      registrado_por: Current.user
    )
    redirect_to admin_membresias_path,
      notice: "Membresía de #{membresia.user.nombre} renovada hasta el #{I18n.l(membresia.fecha_vencimiento, format: :long)}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to edit_admin_membresia_path(membresia), alert: "No se pudo renovar: #{error.message}"
  end
end
