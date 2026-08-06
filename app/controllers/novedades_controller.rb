class NovedadesController < ApplicationController
  before_action { exigir_feature("novedades") }  # Fase 18d

  VERSION_TEXTO_CONSENTIMIENTO = "muro-v1"

  def index
    authorize Novedad
    # policy_scope: solo las del tenant propio (Fase 18f — la Scope existía
    # desde §16.6 pero el controller listaba global).
    @novedades = policy_scope(Novedad).publicadas
    # Muro de la comunidad (Fase 18e): celebraciones derivadas, cero digitación.
    @celebraciones = Comunidad::Muro.celebraciones(Current.tenant)
    @participo = !Current.user.global? &&
                 Consentimiento.vigente?(Current.user, "logros_comunidad")
  end

  # Opt-in del muro: fila append-only auditable, mismo patrón del ranking
  # (TablaPosicionesController#participar). Repetir el POST no re-otorga.
  def participar
    authorize Novedad, :participar?
    unless Consentimiento.vigente?(Current.user, "logros_comunidad")
      registrar_consentimiento!("otorgado")
    end
    redirect_to novedades_path, notice: "Listo: tus logros se celebran con tu gym."
  end

  def retirarse
    authorize Novedad, :participar?
    if Consentimiento.vigente?(Current.user, "logros_comunidad")
      registrar_consentimiento!("revocado")
    end
    redirect_to novedades_path, notice: "Tus logros ya no se comparten. Puedes volver cuando quieras."
  end

  private
    def registrar_consentimiento!(accion)
      Consentimiento.create!(user: Current.user, tipo: "logros_comunidad",
                             accion: accion, version_texto: VERSION_TEXTO_CONSENTIMIENTO,
                             ip: request.remote_ip, user_agent: request.user_agent)
    end
end
