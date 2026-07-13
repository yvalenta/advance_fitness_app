# Resume el seguimiento real del miembro (Fase 6.6) para retroalimentar la
# generación del plan: % global de checks, adherencia por ejercicio y las
# últimas novedades reportadas (lesiones, máquinas ocupadas…). Devuelve nil
# si no hay registros en el rango — el prompt simplemente omite el bloque.
module ResumenAdherencia
  NOVEDADES_MAX = 5

  def self.para(user, semanas: 4)
    desde = Date.current.beginning_of_week - (semanas - 1).weeks
    registros = user.registros_entrenamiento.where(fecha: desde..Date.current)
    return if registros.none?

    conteos = Hash.new { |h, k| h[k] = { hechos: 0, total: 0 } }
    novedades = []

    registros.order(:fecha).each do |registro|
      registro.ejercicios.each do |clave, estado|
        if clave == "novedad"
          novedades << estado if estado.present?
        elsif clave.match?(/\A\d+\z/) && estado.is_a?(Hash)
          nombre = estado["nombre"].presence || "Ejercicio #{clave.to_i + 1}"
          conteos[nombre][:total] += 1
          conteos[nombre][:hechos] += 1 if estado["hecho"]
        end
      end
    end
    return if conteos.empty? && novedades.empty?

    total = conteos.values.sum { |c| c[:total] }
    hechos = conteos.values.sum { |c| c[:hechos] }
    {
      semanas: semanas,
      pct_global: total.zero? ? 0 : (hechos * 100.0 / total).round,
      por_ejercicio: conteos.map { |nombre, c| { nombre: nombre, hechos: c[:hechos], total: c[:total] } },
      novedades: novedades.last(NOVEDADES_MAX)
    }
  end
end
