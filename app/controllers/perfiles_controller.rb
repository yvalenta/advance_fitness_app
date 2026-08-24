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
      # destino por whitelist (Fase 18c): el mini-perfil de objetivos/new
      # devuelve al flujo de fijar objetivo; jamás un path abierto del param.
      destino = if !@user.perfil_nutricional_completo?
        edit_perfil_path
      elsif params[:destino] == "nuevo_objetivo"
        new_objetivo_path
      else
        objetivo_path
      end
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
      @peso_actual = @user.mediciones.recientes.first&.peso_kg
    end

    # rol jamás asignable aquí (SDD §08); tema, acento y wake_lock_activo sí son del usuario
    def perfil_params
      params.expect(user: %i[nombre fecha_nacimiento sexo talla_cm nivel_actividad tema acento wake_lock_activo])
    end
end
