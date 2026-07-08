# Autosave por ejercicio del editor de rutina (SDD Fase 5.7b). Espeja
# GestionComidasController pero en 2D: :dia_id = índice del día,
# :id = índice del ejercicio dentro de ese día. Responde JSON.
class GestionEjerciciosController < ApplicationController
  before_action :cargar_plan

  def create
    @plan.agregar_ejercicio!(dia_indice, ejercicio_params)
    render json: cuerpo, status: :created
  rescue IndexError, KeyError
    render json: { error: "El día ya no existe." }, status: :not_found
  end

  def update
    @plan.actualizar_ejercicio!(dia_indice, params[:id].to_i, ejercicio_params)
    render json: cuerpo
  rescue IndexError, KeyError
    render json: { error: "El ejercicio ya no existe." }, status: :not_found
  end

  def destroy
    @plan.eliminar_ejercicio!(dia_indice, params[:id].to_i)
    render json: cuerpo
  rescue IndexError, KeyError, ActiveRecord::RecordNotFound
    render json: { error: "El ejercicio ya no existe." }, status: :not_found
  end

  private

    def cargar_plan
      @plan = PlanPersonalizado.find(params[:plan_personalizado_id])
      authorize @plan, :editar?
    end

    def dia_indice = params[:dia_id].to_i

    def ejercicio_params
      return {} if params[:ejercicio].blank?

      params.expect(ejercicio: PlanPersonalizado::CAMPOS_EJERCICIO.map(&:to_sym))
    end

    def cuerpo
      { ejercicios: @plan.ejercicios_de(dia_indice) }
    end
end
