# Proyección 1-a-1 del motor de juego (Fase 14.12): caché de lo que dice el
# ledger `registros_puntos` (+ racha y logros). Reconstruible por completo con
# Juego::Recalculador — nada aquí es fuente de verdad salvo las preferencias
# del propio miembro (visible_en_tabla, apodo), que no son derivables.
# La racha vive aquí (no hay tabla propia); la actualiza Juego::Racha.
class PerfilJuego < ApplicationRecord
  include TenantDesnormalizado

  belongs_to :user
  # tenant_id desnormalizado: el leaderboard filtra por columna, sin join.
  hereda_tenant_de :user

  validates :user_id, uniqueness: true
  validate :cuenta_no_se_mudo_antes_de_guardar, if: :nace_o_enciende_visibilidad?

  # Nivel determinista en función de los puntos: raíz entera de (puntos/100)
  # + 1 → 0-99 pts nivel 1, 100-399 nivel 2, 400-899 nivel 3, 900-1599
  # nivel 4… Cuadrática simple: cada nivel cuesta más que el anterior. El
  # clamp evita Math::DomainError si los ajustes manuales dejan total < 0.
  def self.nivel_para(puntos_total)
    Integer.sqrt([ puntos_total, 0 ].max / 100) + 1
  end

  # El juego es de la persona (Nota 29, D1): puntos, nivel, racha y logros
  # viajan con la cuenta cuando cambia de gimnasio. `tenant_id` es solo la
  # cache desnormalizada del tenant del user y se re-sincroniza aquí; si no,
  # la validación de TenantDesnormalizado hace reventar todo `update!` del
  # motor. Lo que NO viaja es la visibilidad: `visible_en_tabla` (el opt-in
  # del ranking del gimnasio viejo) vuelve a false — fail-closed, nadie
  # aparece en una tabla donde no consintió. El apodo es preferencia, se queda.
  # Lo llama el callback de User (`el_juego_sigue_a_la_cuenta`).
  #
  # SIN early-return cuando el tenant del perfil ya coincide con el destino
  # (un perfil desfasado de antes que la cuenta alcanza al volver): el
  # callback revoca el consentimiento en toda mudanza, y la tabla lee el flag,
  # no el consentimiento — saltarse el flag dejaba a la persona listada sin
  # consentimiento. Fail-closed: la visibilidad se apaga siempre; si nada
  # cambia, Rails no escribe.
  def seguir_a_la_cuenta!
    update!(tenant_id: user.tenant_id, visible_en_tabla: false)
  end

  # find_or_create tolerante a la carrera de dos jobs simultáneos: el índice
  # único sobre user_id convierte al perdedor en un retry que ya encuentra.
  def self.para(user)
    find_or_create_by!(user: user)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private
    # Los dos saves que dejan a la persona expuesta en el tenant de la fila:
    # nacer (el perfil entra al leaderboard del tenant que se le escriba) y
    # encender `visible_en_tabla`. Apagar nunca se bloquea: es la dirección
    # segura, y la única que puede pedir quien tenga la cuenta vieja en memoria.
    def nace_o_enciende_visibilidad?
      new_record? || (will_save_change_to_visible_en_tabla? && visible_en_tabla?)
    end

    # La validación de TenantDesnormalizado compara contra la cuenta EN
    # MEMORIA: si quien llama la cargó antes de que commiteara el canje del
    # pase (OtorgarPuntosJob, `participar` en vuelo), el perfil nacía con el
    # tenant viejo y coincidiendo con esa cuenta vieja — y el callback de User
    # ya había corrido sin ver perfil, así que nada lo reparaba. Al CREAR se
    # lee el tenant fresco de la fila con `FOR SHARE`: la validación corre
    # dentro de la transacción del save, así que el candado dura hasta el
    # INSERT y la mudanza (un UPDATE de users) espera — o ya commiteó y se ve,
    # o commitea después y su callback encuentra el perfil y lo sigue. Si la
    # cuenta cargada ya es vieja, se niega (fail-closed, igual que el
    # `update!` de un perfil existente: RecordInvalid); reintentar con la
    # cuenta fresca nace bien.
    #
    # Lo mismo al ENCENDER `visible_en_tabla` (F1, ronda 2): un perfil recién
    # creado con la cuenta vieja en memoria nace bien, la mudanza lo muda y lo
    # apaga, y el `update!` siguiente comparaba esa cuenta vieja contra el
    # tenant viejo del propio objeto — pasaba, y como Rails escribe solo las
    # columnas que cambiaron la fila quedaba EN el tenant nuevo y VISIBLE. El
    # tenant que vio quien enciende (`tenant_id` en memoria) debe seguir siendo
    # el fresco de la cuenta.
    def cuenta_no_se_mudo_antes_de_guardar
      return if user_id.nil?

      fresco = User.lock("FOR SHARE").where(id: user_id).pick(:tenant_id)
      errors.add(:tenant_id, "debe coincidir con el de user") if fresco != tenant_id
    end
end
