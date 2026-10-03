# El juego es de la persona (Nota 29, D1): el perfil de juego sigue a la
# cuenta cuando cambia de gimnasio. El código nuevo (User#el_juego_sigue_a_la_cuenta)
# lo mantiene coherente de aquí en adelante; esta migración arregla los
# perfiles que YA quedaron desfasados — `perfiles_juego.tenant_id` distinto de
# `users.tenant_id` por haber cambiado de gimnasio con el código anterior — y
# en los que todo `perfil.update!` (racha, puntos, recordatorio) revienta con
# "Tenant debe coincidir con el de user".
#
# Va DENTRO de la migración, mismo criterio que `crear_puestos`: el valor es
# derivable y determinista (la verdad es `users.tenant_id`), y un rake aparte
# abriría una ventana entre el deploy y su ejecución en la que el perfil sigue
# roto. Set-based, dos sentencias; idempotente (una segunda corrida ya no
# encuentra desfasados).
#
# Misma regla de privacidad que el código vivo, fail-closed: el opt-in del
# ranking (`visible_en_tabla`) y los consentimientos de visibilidad se dieron
# en el gimnasio viejo y no viajan — `visible_en_tabla` vuelve a false y se
# revocan, con rastro append-only, los consentimientos `tabla_posiciones` y
# `logros_comunidad` que seguían vigentes. Los literales van sin referenciar
# el modelo, para que la migración no cambie si el modelo cambia.
class ResincronizarTenantDePerfilesJuego < ActiveRecord::Migration[8.1]
  def up
    # El rastro va PRIMERO: el JOIN necesita el desfase todavía vivo para saber
    # a quién se le aplica. DISTINCT ON toma la fila vigente (la más reciente)
    # por (usuario, tipo); solo se revoca la que seguía "otorgado".
    # `clock_timestamp()` y no NOW(): NOW() es el inicio de la transacción, y
    # una fila de consentimiento escrita después de ese instante quedaría
    # POR ENCIMA de la revocación en `Consentimiento.vigente?` (última por
    # created_at) — el opt-in seguiría vigente.
    execute <<~SQL.squish
      INSERT INTO consentimientos (user_id, tipo, accion, version_texto, created_at)
      SELECT vigente.user_id, vigente.tipo, 'revocado', 'cambio-de-gimnasio', clock_timestamp()
      FROM (
        SELECT DISTINCT ON (c.user_id, c.tipo) c.user_id, c.tipo, c.accion
        FROM consentimientos c
        JOIN perfiles_juego p ON p.user_id = c.user_id
        JOIN users u ON u.id = p.user_id
        WHERE p.tenant_id IS DISTINCT FROM u.tenant_id
          AND c.tipo IN ('tabla_posiciones', 'logros_comunidad')
        ORDER BY c.user_id, c.tipo, c.created_at DESC, c.id DESC
      ) vigente
      WHERE vigente.accion = 'otorgado'
    SQL

    execute <<~SQL.squish
      UPDATE perfiles_juego p
      SET tenant_id = u.tenant_id, visible_en_tabla = FALSE
      FROM users u
      WHERE u.id = p.user_id
        AND p.tenant_id IS DISTINCT FROM u.tenant_id
    SQL
  end

  # Corrección de datos sin vuelta atrás: el tenant viejo no se guardó y
  # reponerlo reabriría el bug. No-op a propósito.
  def down; end
end
