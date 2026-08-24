module Juego
  # Volumen entrenado por grupo muscular (mapa muscular / body diagram):
  # suma DetalleEntrenamiento.volumen_kg agrupado por Ejercicio.musculo en
  # el período elegido. Normaliza contra el músculo con más volumen para que
  # la vista sombree la intensidad (0..1), y lista los músculos sin trabajar
  # (para que el miembro note el hueco, como el "no entrenado" de referencia).
  class MapaMuscular
    PERIODOS_DIAS = { semana: 7, mes: 30, todo: nil }.freeze

    def self.para(user, periodo: :semana)
      raise ArgumentError, "periodo inválido: #{periodo}" unless PERIODOS_DIAS.key?(periodo)

      detalles = DetalleEntrenamiento.joins(:registro_entrenamiento, :ejercicio)
                                     .where(registro_entrenamiento: { user_id: user.id })
      dias = PERIODOS_DIAS[periodo]
      detalles = detalles.where(registro_entrenamiento: { fecha: (Date.current - (dias - 1))..Date.current }) if dias

      volumen_bd = detalles.group("ejercicios.musculo")
                           .sum("detalle_entrenamientos.repeticiones * COALESCE(detalle_entrenamientos.peso_kg, 0)")
      por_musculo = PlantillaEjercicio::MUSCULOS.index_with { |musculo| volumen_bd[musculo].to_f }
      maximo = por_musculo.values.max.to_f

      { periodo: periodo, por_musculo: por_musculo,
        intensidad: por_musculo.transform_values { |volumen| maximo.positive? ? (volumen / maximo).round(2) : 0 },
        sin_trabajar: por_musculo.reject { |musculo, volumen| volumen.positive? || musculo == "otro" }.keys }
    end
  end
end
