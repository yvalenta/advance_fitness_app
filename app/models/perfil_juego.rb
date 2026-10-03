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
  def seguir_a_la_cuenta!
    return if tenant_id == user.tenant_id

    update!(tenant_id: user.tenant_id, visible_en_tabla: false)
  end

  # find_or_create tolerante a la carrera de dos jobs simultáneos: el índice
  # único sobre user_id convierte al perdedor en un retry que ya encuentra.
  def self.para(user)
    find_or_create_by!(user: user)
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
