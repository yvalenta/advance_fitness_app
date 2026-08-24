module Juego
  # Heatmap de actividad estilo GitHub: mismo criterio de "día cumplido" que
  # Juego::Racha y el dashboard "Hoy" (check-in O al menos un ejercicio
  # marcado hecho), extendido a un rango de fechas para pintar la cuadrícula.
  # Nivel 0-3 para la intensidad de sombreado:
  #   0 nada · 1 solo check-in · 2 solo entrenamiento marcado · 3 ambos
  class Heatmap
    def self.para(user, desde:, hasta:)
      con_acceso = user.accesos.where(fecha_hora: desde.beginning_of_day..hasta.end_of_day)
                       .pluck(:fecha_hora).map(&:to_date).to_set
      con_marca = user.registros_entrenamiento.where(fecha: desde..hasta)
                      .select { |registro| registro.conteo_hechos.positive? }
                      .map(&:fecha).to_set

      (desde..hasta).map do |fecha|
        nivel = (con_acceso.include?(fecha) ? 1 : 0) + (con_marca.include?(fecha) ? 2 : 0)
        { fecha: fecha, nivel: nivel }
      end
    end

    # Agrupa el resultado de `.para` en columnas de semana (lunes-domingo)
    # para pintar la cuadrícula estilo GitHub — con celdas vacías
    # (nivel: nil) para completar la primera/última semana.
    def self.en_columnas(dias)
      return [] if dias.empty?

      por_fecha = dias.index_by { |dia| dia[:fecha] }
      inicio = dias.first[:fecha].beginning_of_week
      fin = dias.last[:fecha].end_of_week
      (inicio..fin).map { |fecha| por_fecha[fecha] || { fecha: fecha, nivel: nil } }
                  .each_slice(7).to_a
    end
  end
end
