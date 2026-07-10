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
      # Con la meta definida ya se puede crear el plan sugerido de la
      # membresía, si el miembro no tiene ninguno (Fase 5.11).
      PlanPersonalizado.asegurar_sugerido!(Current.user)
      redirect_to objetivo_path, notice: "Objetivo fijado: #{@objetivo.objetivo_kcal} kcal diarias."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Ajuste manual del objetivo diario (Fase 5.11): solo cambia el kcal vigente,
  # el snapshot (peso, TDEE) se conserva como referencia del cálculo.
  def update
    @objetivo = Current.user.objetivo_activo
    authorize(@objetivo || ObjetivoNutricional, :update?)
    return redirect_to new_objetivo_path, alert: "Primero fija tu objetivo." unless @objetivo

    kcal = params.dig(:objetivo_nutricional, :objetivo_kcal).to_i

    if kcal.positive? && @objetivo.update(objetivo_kcal: kcal)
      redirect_to objetivo_path, notice: "Objetivo diario ajustado a #{kcal} kcal."
    else
      redirect_to objetivo_path, alert: "El objetivo debe ser un número mayor que cero."
    end
  end

  private

    def exigir_perfil_completo
      return if Current.user.perfil_nutricional_completo?

      authorize ObjetivoNutricional, :create?
      redirect_to edit_perfil_path, alert: "Completa tu perfil para calcular tu objetivo calórico."
    end
end
