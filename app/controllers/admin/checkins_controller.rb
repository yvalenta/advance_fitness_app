class Admin::CheckinsController < ApplicationController
  def index
    authorize Acceso
    @busqueda = params[:q].to_s.strip
    @miembros =
      if @busqueda.present?
        User.where("nombre ILIKE :q OR email_address ILIKE :q", q: "%#{@busqueda}%")
            .includes(:membresia).order(:nombre).limit(10)
      else
        User.none
      end
    @accesos = policy_scope(Acceso).recientes.includes(:user).limit(10)
  end

  # Flujo D del SDD: valida membresía activa + horario antes de registrar
  def create
    miembro = User.find(params[:user_id])
    authorize Acceso.new(user: miembro)
    membresia = miembro.membresia

    if membresia.nil?
      return redirect_to admin_checkins_path, alert: "#{miembro.nombre} no tiene membresía. Créala antes de registrar el acceso."
    end
    if !membresia.activa?
      return redirect_to admin_checkins_path, alert: "La membresía de #{miembro.nombre} está #{membresia.estado}. Registra la renovación."
    end

    acceso = Acceso.registrar_para(miembro, membresia)
    if acceso.dentro_de_horario?
      redirect_to admin_checkins_path, notice: "#{tipo_legible(acceso)} registrado para #{miembro.nombre}."
    else
      redirect_to admin_checkins_path, alert: "#{tipo_legible(acceso)} registrado FUERA de horario para #{miembro.nombre}."
    end
  end

  private
    def tipo_legible(acceso)
      acceso.tipo == "reingreso" ? "Reingreso" : "Check-in"
    end
end
