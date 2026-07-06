class RegistrosCaloriasController < ApplicationController
  def create
    authorize RegistroCaloria, :create?
    datos = params.expect(registro_caloria: [ :kcal_consumidas ])
    registro = RegistroCaloria.registrar(Current.user, kcal: datos[:kcal_consumidas])

    if registro.persisted? && registro.errors.none?
      redirect_to objetivo_path, notice: "Consumo de hoy registrado."
    else
      redirect_to objetivo_path, alert: registro.errors.full_messages.to_sentence
    end
  end
end
