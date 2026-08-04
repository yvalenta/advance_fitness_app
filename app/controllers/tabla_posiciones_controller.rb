# Tabla de posiciones del gimnasio (Fase 14.14) — la vista más sensible del
# producto white-label: muestra datos ENTRE miembros. Tres defensas apiladas:
#
#   1. Tenant: TODO pasa por policy_scope (tenant_id directo, fail-closed) —
#      un miembro de otro gimnasio jamás aparece, tenga los puntos que tenga.
#   2. Opt-in doble (Fase 14.11): fila de Consentimiento auditable + flag
#      `visible_en_tabla` en el perfil PROPIO, en una sola transacción. La
#      policy restringe el flag al dueño — el staff no lo activa por nadie.
#   3. Reciprocidad: quien no participa ve la lista borrosa sin datos reales.
#
# El ledger (`registros_puntos`) NUNCA se toca desde aquí: esta vista solo
# lee la proyección `perfiles_juego` que mantiene el motor de juego (14.12).
class TablaPosicionesController < ApplicationController
  LIMITE = 50
  VERSION_TEXTO_CONSENTIMIENTO = "ranking-v1"

  before_action :solo_miembros_de_tenant

  # Leaderboard en 3 queries (cero N+1): top 50 + preload de sus users, y una
  # tercera para la posición propia (cuántos me superan + 1) — solo si participo.
  #
  # Empates: a mismo `puntos_total` gana quien llegó primero — `updated_at asc`,
  # porque quien alcanzó esa cifra hace más tiempo tiene el perfil sin retocar
  # desde entonces; el recién llegado al empate aparece debajo.
  def index
    authorize PerfilJuego, :index?
    @mi_perfil = Current.user.perfil_juego
    @participo = @mi_perfil&.visible_en_tabla? || false
    return unless @participo

    visibles = policy_scope(PerfilJuego).where(visible_en_tabla: true)
    @top = visibles.includes(:user)
                   .order(puntos_total: :desc, updated_at: :asc)
                   .limit(LIMITE).to_a
    @mi_posicion = visibles.where("puntos_total > ?", @mi_perfil.puntos_total).count + 1
    @en_top = @top.any? { |perfil| perfil.id == @mi_perfil.id }
  end

  # Opt-in (y edición de apodo). El perfil operado es SIEMPRE el de
  # Current.user — no se acepta ningún user_id: por diseño es imposible
  # activar la visibilidad de otro, y la policy lo re-verifica (update? solo
  # del dueño). Si ya participaba, solo actualiza el apodo sin ensuciar el
  # registro append-only con re-otorgamientos.
  def participar
    perfil = PerfilJuego.para(Current.user)
    authorize perfil, :update?

    ya_participaba = perfil.visible_en_tabla?
    ApplicationRecord.transaction do
      registrar_consentimiento!("otorgado") unless ya_participaba
      perfil.update!(visible_en_tabla: true, apodo: apodo_param)
    end

    aviso = ya_participaba ? "Apodo actualizado." : "Ya estás en la tabla de posiciones."
    redirect_to ranking_path, notice: aviso
  end

  # Opt-out: fila de revocación + flag abajo, misma transacción. El apodo se
  # conserva (es una preferencia, no un dato publicado).
  def retirarse
    perfil = Current.user.perfil_juego

    if perfil.nil? || !perfil.visible_en_tabla?
      skip_authorization
      return redirect_to ranking_path, notice: "No estabas en la tabla de posiciones."
    end

    authorize perfil, :update?
    ApplicationRecord.transaction do
      registrar_consentimiento!("revocado")
      perfil.update!(visible_en_tabla: false)
    end

    redirect_to ranking_path, notice: "Saliste de la tabla. Puedes volver cuando quieras."
  end

  private
    # El ranking es de los miembros DE un gimnasio: superadmin/comercializador
    # no compiten ni consienten — redirect elegante en vez de scope vacío mudo.
    def solo_miembros_de_tenant
      return unless Current.user&.global?

      skip_authorization
      redirect_to root_path, alert: "La tabla de posiciones es de los miembros del gimnasio."
    end

    def registrar_consentimiento!(accion)
      Consentimiento.create!(user: Current.user, tipo: "tabla_posiciones",
                             accion: accion, version_texto: VERSION_TEXTO_CONSENTIMIENTO,
                             ip: request.remote_ip, user_agent: request.user_agent)
    end

    def apodo_param
      params.expect(perfil_juego: [ :apodo ])[:apodo].presence
    end

    # Lo que promete el texto del opt-in: apodo o nombre de pila — jamás el
    # correo. El fallback "Miembro" cubre perfiles sin nombre ni apodo.
    helper_method def nombre_en_ranking(perfil)
      perfil.apodo.presence || perfil.user.nombre.to_s.split.first.presence || "Miembro"
    end
end
