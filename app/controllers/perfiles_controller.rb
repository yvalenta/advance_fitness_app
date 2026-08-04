class PerfilesController < ApplicationController
  def edit
    @user = Current.user
    authorize @user, :update?
    cargar_stats
  end

  def update
    @user = Current.user
    authorize @user, :update?

    if @user.update(perfil_params)
      destino = @user.perfil_nutricional_completo? ? objetivo_path : edit_perfil_path
      redirect_to destino, notice: "Perfil actualizado."
    else
      cargar_stats # el render :edit también pinta la cabecera de stats
      render :edit, status: :unprocessable_entity
    end
  end

  private

    # Cabecera con stats (Fase 16.4, referencia Pulse). find_or_initialize:
    # mirar el perfil no siembra filas del motor de juego (patrón dashboard).
    def cargar_stats
      @total_entrenamientos = @user.registros_entrenamiento.count
      @perfil_juego = PerfilJuego.find_or_initialize_by(user: @user)
      @records_total = @user.records_personales.vigentes.count
    end

    # rol jamás asignable aquí (SDD §08); tema sí es del usuario (Fase 16)
    def perfil_params
      params.expect(user: %i[nombre fecha_nacimiento sexo talla_cm nivel_actividad tema])
    end
end
