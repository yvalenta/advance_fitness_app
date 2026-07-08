class Entrenador::PlantillasEjercicioController < ApplicationController
  # "Guardar como plantilla" desde el editor de rutina: responde JSON para
  # actualizar el picker sin perder lo editado (espeja PlantillasComida).
  def create
    authorize PlantillaEjercicio
    plantilla = PlantillaEjercicio.new(plantilla_params)
    plantilla.creado_por = Current.user

    if plantilla.save
      render json: plantilla.as_json(only: %i[id musculo nombre series repeticiones descanso_seg]),
             status: :created
    else
      render json: { errores: plantilla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    plantilla = PlantillaEjercicio.find(params[:id])
    authorize plantilla
    plantilla.destroy!
    redirect_back fallback_location: entrenador_borradores_path, notice: "Plantilla eliminada."
  end

  private

    def plantilla_params
      params.expect(plantilla_ejercicio: %i[musculo nombre series repeticiones descanso_seg])
    end
end
