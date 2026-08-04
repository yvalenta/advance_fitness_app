# Credenciales de la cuenta (Fase 17, Nota 22): cambiar correo y/o
# contraseña exige SIEMPRE probar la contraseña actual — password_challenge,
# que has_secure_password valida nativamente (en blanco u omitido, falla).
# Separado de PerfilesController a propósito: credenciales y datos
# corporales no comparten strong params ni nivel de riesgo.
class CuentasController < ApplicationController
  def update
    @user = Current.user
    authorize @user, :update?

    cambia_password = cuenta_params[:password].present?
    if @user.update(cuenta_params)
      # Al cambiar la contraseña, las DEMÁS sesiones abiertas se cierran:
      # si alguien más tenía la cuenta abierta, queda fuera.
      @user.sessions.where.not(id: Current.session.id).delete_all if cambia_password
      redirect_to edit_perfil_path, notice: "Credenciales actualizadas."
    else
      redirect_to edit_perfil_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  private

    def cuenta_params
      @cuenta_params ||= begin
        permitidos = params.expect(user: %i[email_address password password_confirmation password_challenge])
        # Sin contraseña nueva (solo correo) no viajan las claves de password
        permitidos = permitidos.except(:password, :password_confirmation) if permitidos[:password].blank?
        # El challenge SIEMPRE se asigna: omitirlo en el request no lo salta
        permitidos[:password_challenge] = permitidos[:password_challenge].to_s
        permitidos
      end
    end
end
