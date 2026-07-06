class PerfilesController < ApplicationController
  def edit
    @user = Current.user
    authorize @user, :update?
  end

  def update
    @user = Current.user
    authorize @user, :update?

    if @user.update(perfil_params)
      destino = @user.perfil_nutricional_completo? ? objetivo_path : edit_perfil_path
      redirect_to destino, notice: "Perfil actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    # rol jamás asignable aquí (SDD §08)
    def perfil_params
      params.expect(user: %i[nombre fecha_nacimiento sexo talla_cm nivel_actividad])
    end
end
