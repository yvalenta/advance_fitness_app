class Entrenador::PlantillasComidaController < ApplicationController
  # "Guardar como plantilla" llega por fetch desde el editor del plan:
  # responde JSON para que el picker se actualice sin perder lo editado.
  def create
    authorize PlantillaComida
    plantilla = PlantillaComida.new(plantilla_params)
    plantilla.creado_por = Current.user

    if plantilla.save
      render json: plantilla.as_json(only: %i[id tipo nombre descripcion kcal
                                              proteinas_g carbohidratos_g grasas_g]),
             status: :created
    else
      render json: { errores: plantilla.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    plantilla = PlantillaComida.find(params[:id])
    authorize plantilla
    plantilla.destroy!
    redirect_back fallback_location: entrenador_borradores_path, notice: "Plantilla eliminada."
  end

  private

    def plantilla_params
      params.expect(plantilla_comida: %i[tipo nombre descripcion kcal
                                         proteinas_g carbohidratos_g grasas_g])
    end
end
