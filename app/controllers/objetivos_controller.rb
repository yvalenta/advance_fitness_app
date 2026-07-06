class ObjetivosController < ApplicationController
  before_action :exigir_perfil_completo, only: %i[new create]

  def show
    @objetivo = Current.user.objetivo_activo
    authorize @objetivo || Current.user.objetivos_nutricionales.new, :show?
    @registro_hoy = Current.user.registros_calorias.find_by(fecha: Date.current)
    @registros = Current.user.registros_calorias.order(fecha: :desc).limit(7)
  end

  def new
    authorize ObjetivoNutricional, :create?
    @objetivo = ObjetivoNutricional.new(peso_kg: Current.user.objetivo_activo&.peso_kg)
  end

  def create
    authorize ObjetivoNutricional, :create?
    datos = params.expect(objetivo_nutricional: %i[tipo peso_kg])
    @objetivo = ObjetivoNutricional.fijar_para(Current.user, tipo: datos[:tipo], peso_kg: datos[:peso_kg])

    if @objetivo.persisted?
      redirect_to objetivo_path, notice: "Objetivo fijado: #{@objetivo.objetivo_kcal} kcal diarias."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

    def exigir_perfil_completo
      return if Current.user.perfil_nutricional_completo?

      authorize ObjetivoNutricional, :create?
      redirect_to edit_perfil_path, alert: "Completa tu perfil para calcular tu objetivo calórico."
    end
end
