class Admin::CheckinsController < ApplicationController
  before_action { exigir_feature("membresias") }  # Fase 18d
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

  # Flujo D del SDD: valida el acceso antes de registrar. El plan personalizado
  # activo reemplaza la mensualidad, así que un miembro premium entra aunque no
  # tenga membresía mensual activa (SDD §10, regla de negocio).
  def create
    miembro = User.find(params[:user_id])
    authorize Acceso.new(user: miembro)
    membresia = miembro.membresia

    unless membresia&.activa? || miembro.premium?
      motivo = membresia.nil? ? "no tiene membresía" : "tiene la membresía #{membresia.estado}"
      return redirect_to admin_checkins_path,
                         alert: "#{miembro.nombre} #{motivo} y no tiene plan personalizado activo. Registra su membresía o renovación."
    end

    acceso = Acceso.registrar_para(miembro, membresia)
    # Motor de juego (Fase 14.12): puntos y racha en background, encolados
    # desde el controller — jamás desde callbacks del modelo (demo:sembrar
    # crearía miles de accesos con puntos y el check-in es sensible a
    # latencia). El acceso es el origen: la constraint única del ledger
    # absorbe cualquier reintento duplicado.
    OtorgarPuntosJob.perform_later(miembro.id, tipo: "checkin",
                                   fecha: acceso.fecha_hora.to_date,
                                   origen_gid: acceso.to_global_id.to_s)
    via_premium = !membresia&.activa? && miembro.premium?

    if !acceso.dentro_de_horario?
      redirect_to admin_checkins_path, alert: "#{tipo_legible(acceso)} registrado FUERA de horario para #{miembro.nombre}."
    elsif via_premium
      redirect_to admin_checkins_path, notice: "#{tipo_legible(acceso)} registrado para #{miembro.nombre} (acceso por plan personalizado)."
    else
      redirect_to admin_checkins_path, notice: "#{tipo_legible(acceso)} registrado para #{miembro.nombre}."
    end
  end

  private
    def tipo_legible(acceso)
      acceso.tipo == "reingreso" ? "Reingreso" : "Check-in"
    end
end
