class OmniauthSessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ create failure ]

  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    start_new_session_for user
    redirect_to after_authentication_url
  rescue ActiveRecord::RecordInvalid
    redirect_to new_session_path, alert: "No se pudo iniciar sesión con Google."
  end

  def failure
    redirect_to new_session_path, alert: "No se pudo iniciar sesión con Google."
  end
end
