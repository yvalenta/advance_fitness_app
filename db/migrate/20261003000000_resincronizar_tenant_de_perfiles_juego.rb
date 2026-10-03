# El juego es de la persona (Nota 29, D1): el perfil de juego sigue a la
# cuenta cuando cambia de gimnasio. El código nuevo (User#el_juego_sigue_a_la_cuenta)
# lo mantiene coherente de aquí en adelante; esta migración arregla lo que el
# código anterior ya dejó: los perfiles con `perfiles_juego.tenant_id` distinto
# de `users.tenant_id` (en los que todo `perfil.update!` — racha, puntos,
# recordatorio — revienta con "Tenant debe coincidir con el de user") y los
# opt-in de visibilidad que siguen vigentes en cuentas que ya se mudaron.
#
# Va DENTRO de la migración, mismo criterio que `crear_puestos`: el valor es
# derivable y determinista (la verdad es `users.tenant_id`), y un rake aparte
# abriría una ventana entre el deploy y su ejecución en la que el perfil sigue
# roto. Set-based; idempotente (una segunda corrida ya no encuentra nada).
#
# Misma regla de privacidad que el código vivo, fail-closed: el opt-in del
# ranking (`visible_en_tabla`) y los consentimientos de visibilidad se dieron
# en el gimnasio viejo y no viajan — se revocan, con rastro append-only,
# `tabla_posiciones` y `logros_comunidad`, y `visible_en_tabla` vuelve a false.
#
# QUIÉN se mudó y CUÁNDO lo dice `cambios_organizacion` (el embudo escribe su
# fila en la misma transacción que `estacionar_en!`), no el perfil: hay
# cuentas que se mudaron sin perfil o cuyo perfil nació ya en el gimnasio
# nuevo — su tenant coincide, no se delatan por desfase — y siguen en el muro
# del nuevo con el `logros_comunidad` del viejo. Y la fecha decide qué se
# revoca: solo el opt-in dado ANTES de la última mudanza es del gimnasio viejo;
# uno dado DESPUÉS es legítimo del nuevo y no se toca (ni se le escribe un
# rastro «cambio-de-gimnasio» que mentiría). Los literales van sin referenciar
# el modelo, para que la migración no cambie si el modelo cambia.
class ResincronizarTenantDePerfilesJuego < ActiveRecord::Migration[8.1]
  # Última mudanza real por cuenta. Solo cuentan las filas CON pase
  # (`token_digest`: el canje que llamó a `estacionar_en!`) y de un tenant a
  # otro: la fila de auditoría del superadmin (sin pase, `de_tenant_id` nil) no
  # mueve nada, y un pase canjeado dentro del mismo gimnasio tampoco.
  MUDANZAS = <<~SQL.squish
    SELECT user_id, MAX(created_at) AS mudado_en
    FROM cambios_organizacion
    WHERE token_digest IS NOT NULL AND de_tenant_id IS DISTINCT FROM a_tenant_id
    GROUP BY user_id
  SQL

  def up
    # El rastro va PRIMERO: la rama sin fila de mudanza necesita el desfase
    # todavía vivo. DISTINCT ON toma la fila vigente (la más reciente) por
    # (usuario, tipo); solo se revoca la que seguía "otorgado".
    #   · con fila de mudanza: si es anterior (o igual) a la última mudanza,
    #     es del gimnasio viejo — igual o anterior, no solo anterior: ante el
    #     empate se revoca (fail-closed).
    #   · sin fila: no hay fecha que comparar (una mudanza fuera del embudo,
    #     p. ej. a mano); queda la regla vieja — perfil desfasado revoca todo
    #     lo vigente.
    # `clock_timestamp()` y no NOW(): NOW() es el inicio de la transacción, y
    # una fila de consentimiento escrita después de ese instante quedaría
    # POR ENCIMA de la revocación en `Consentimiento.vigente?` (última por
    # created_at) — el opt-in seguiría vigente.
    execute <<~SQL.squish
      INSERT INTO consentimientos (user_id, tipo, accion, version_texto, created_at)
      SELECT vigente.user_id, vigente.tipo, 'revocado', 'cambio-de-gimnasio', clock_timestamp()
      FROM (
        SELECT DISTINCT ON (c.user_id, c.tipo) c.user_id, c.tipo, c.accion, c.created_at
        FROM consentimientos c
        WHERE c.tipo IN ('tabla_posiciones', 'logros_comunidad')
        ORDER BY c.user_id, c.tipo, c.created_at DESC, c.id DESC
      ) vigente
      LEFT JOIN (#{MUDANZAS}) mudanza ON mudanza.user_id = vigente.user_id
      WHERE vigente.accion = 'otorgado'
        AND CASE
              WHEN mudanza.mudado_en IS NOT NULL THEN vigente.created_at <= mudanza.mudado_en
              ELSE EXISTS (
                SELECT 1 FROM perfiles_juego p JOIN users u ON u.id = p.user_id
                WHERE p.user_id = vigente.user_id AND p.tenant_id IS DISTINCT FROM u.tenant_id)
            END
    SQL

    execute <<~SQL.squish
      UPDATE perfiles_juego p
      SET tenant_id = u.tenant_id, visible_en_tabla = FALSE
      FROM users u
      WHERE u.id = p.user_id
        AND p.tenant_id IS DISTINCT FROM u.tenant_id
    SQL

    # La tabla lee el flag, no el consentimiento: quien volvió al gimnasio de
    # su perfil (A → B → A: el tenant del perfil coincide, no hay desfase que
    # lo apague arriba) y perdió el opt-in recién revocado no puede seguir
    # visible. Solo cuentas con mudanza: no se toca el resto del flag.
    execute <<~SQL.squish
      UPDATE perfiles_juego p
      SET visible_en_tabla = FALSE
      FROM (#{MUDANZAS}) mudanza
      WHERE mudanza.user_id = p.user_id
        AND p.visible_en_tabla
        AND (SELECT c.accion FROM consentimientos c
             WHERE c.user_id = p.user_id AND c.tipo = 'tabla_posiciones'
             ORDER BY c.created_at DESC, c.id DESC LIMIT 1) IS DISTINCT FROM 'otorgado'
    SQL
  end

  # Corrección de datos sin vuelta atrás: el tenant viejo no se guardó y
  # reponerlo reabriría el bug. No-op a propósito.
  def down; end
end
