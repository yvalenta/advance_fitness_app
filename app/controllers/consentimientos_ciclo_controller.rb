# Consentimiento del módulo de ciclo (Fase 14.15), sobre la infraestructura
# append-only de la Fase 14.11. Dos tipos SEPARADOS a propósito:
#   * `ciclo_menstrual`    — guardar y ver sus propios registros.
#   * `ciclo_menstrual_ia` — opcional: usar la fase para personalizar el plan
#                            (el análisis lo hace un proveedor de IA externo).
#     En esta etapa solo se CAPTURA; el dato jamás viaja al prompt de IA
#     todavía — el enganche llega con la composición del plan.
# Otorgar y revocar crean filas nuevas (nunca se edita ni borra el rastro).
# Revocar el tipo base revoca también el de IA y, salvo que la usuaria
# marque "conservar mis datos", borra sus ciclos físicamente en la misma
# transacción (CicloMenstrual.revocar!).
class ConsentimientosCicloController < ApplicationController
  def create
    autorizar_consentimiento_propio

    if params[:ambito] == "ia"
      # El opt-in de IA solo tiene sentido con el consentimiento base activo.
      otorgar("ciclo_menstrual_ia", CicloMenstrual::VERSION_TEXTO_IA) if base_vigente?
      redirect_to progreso_path, notice: "Listo: tu fase podrá usarse para personalizar tu plan."
    else
      otorgar("ciclo_menstrual", CicloMenstrual::VERSION_TEXTO)
      if params.dig(:consentimiento_ciclo, :acepta_ia) == "1"
        otorgar("ciclo_menstrual_ia", CicloMenstrual::VERSION_TEXTO_IA)
      end
      redirect_to progreso_path, notice: "Consentimiento registrado. Tu ciclo es solo tuyo: el staff nunca lo ve."
    end
  end

  def destroy
    autorizar_consentimiento_propio # revocar también es crear una fila (revocado) propia

    if params[:ambito] == "ia"
      revocar_solo_ia
      redirect_to progreso_path, notice: "Tu fase ya no se usará para personalizar tu plan."
    else
      conservar = params[:conservar_datos] == "1"
      CicloMenstrual.revocar!(Current.user, conservar_datos: conservar,
                              ip: request.remote_ip, user_agent: request.user_agent)
      aviso = conservar ? "Consentimiento revocado. Tus registros quedan guardados por si vuelves." :
                          "Consentimiento revocado y registros borrados."
      redirect_to progreso_path, notice: aviso
    end
  end

  private
    def autorizar_consentimiento_propio
      authorize Consentimiento.new(user: Current.user), :create?
    end

    def base_vigente?
      Consentimiento.vigente?(Current.user, "ciclo_menstrual")
    end

    def otorgar(tipo, version)
      # Idempotente ante doble clic: si ya está vigente no apila otra fila.
      return if Consentimiento.vigente?(Current.user, tipo)

      Current.user.consentimientos.create!(tipo:, accion: "otorgado", version_texto: version,
                                           ip: request.remote_ip, user_agent: request.user_agent)
    end

    def revocar_solo_ia
      return unless Consentimiento.vigente?(Current.user, "ciclo_menstrual_ia")

      Current.user.consentimientos.create!(tipo: "ciclo_menstrual_ia", accion: "revocado",
                                           version_texto: CicloMenstrual::VERSION_TEXTO_IA,
                                           ip: request.remote_ip, user_agent: request.user_agent)
    end
end
