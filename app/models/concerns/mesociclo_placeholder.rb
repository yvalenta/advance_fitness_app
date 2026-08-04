# PLACEHOLDER 14.9 — descartado en la integración a favor de la implementación real de 14.7.
#
# Contrato mínimo de SOLO LECTURA del mesociclo (Fase 14) para que la UI del
# eje de semanas (14.9) compile y sus specs pasen sin la capa de modelo real:
# - Un plan v1 (rutina sin "version") se comporta como mesociclo de 1 semana
#   identidad: `semanas` devuelve una sola semana cuyos días son los de la
#   rutina base y `semana_actual` es 1.
# - Un plan v2 lee `rutina["semanas"]` (claves opcionales por semana:
#   "etiqueta", "descarga", "ajuste", "dias").
# - NO aplica el "ajuste" (la resolución real es de 14.7): los días de una
#   semana sin días propios son los de la rutina base tal cual.
# - "Materializada" = la semana trae sus propios "dias" en el jsonb.
#
# Se engancha en PlanPersonalizado con UNA línea de `include` al FINAL de la
# clase: el hook `included` hace alias del `dias` sin argumentos que la clase
# ya define y lo envuelve para aceptar `semana:` (con `prepend` los specs no
# podrían stubear el contrato: any_instance no soporta módulos prepended).
module MesocicloPlaceholder
  extend ActiveSupport::Concern

  included do
    alias_method :dias_base, :dias

    # Días RESUELTOS de una semana (identidad en el placeholder). Sin
    # `semana:` conserva el contrato histórico: los días base de la rutina.
    def dias(semana: nil)
      return dias_base if semana.nil?

      Array(self.semana(semana)&.[]("dias") || dias_base)
    end
  end

  # Eje completo del mesociclo: array de hashes normalizados
  # {"numero","etiqueta","descarga","ajuste","dias"}.
  def semanas
    brutas = rutina["version"].to_i >= 2 ? Array(rutina["semanas"]) : []
    return [ semana_identidad ] if brutas.empty?

    brutas.each_with_index.map do |semana, indice|
      { "numero" => indice + 1,
        "etiqueta" => semana["etiqueta"].presence || "Semana #{indice + 1}",
        "descarga" => semana["descarga"] == true,
        "ajuste" => semana["ajuste"],
        "dias" => Array(semana["dias"].presence || dias_base) }
    end
  end

  def semana(numero) = semanas.find { |s| s["numero"] == numero.to_i }

  # Semana en curso, clamp 1..total: semanas calendario transcurridas desde la
  # semana en que nació el plan (ancla mínima; el cálculo real es de 14.7).
  def semana_actual
    return 1 unless created_at

    transcurridas = ((Date.current.beginning_of_week - created_at.to_date.beginning_of_week) / 7).to_i + 1
    transcurridas.clamp(1, semanas.size)
  end

  def mesociclo_completado?
    ultima = semanas.size
    total_dias = dias(semana: ultima).size
    return false if ultima <= 1 || total_dias.zero?

    Date.current > Rutina::Calendario.fecha_de(self, semana: ultima, dia_indice: total_dias - 1)
  end

  def semana_materializada?(numero)
    return false unless rutina["version"].to_i >= 2

    Array(rutina["semanas"])[numero.to_i - 1]&.key?("dias") || false
  end

  private

    def semana_identidad
      { "numero" => 1, "etiqueta" => "Semana 1", "descarga" => false,
        "ajuste" => nil, "dias" => dias_base }
    end
end
