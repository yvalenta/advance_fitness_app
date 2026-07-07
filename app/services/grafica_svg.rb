# Normaliza series numéricas a coordenadas SVG (gráficas server-rendered,
# SDD §14 — cero JS). PORO puro: recibe valores, devuelve puntos.
module GraficaSvg
  MARGEN = 14

  # Puntos [x, y] equiespaciados en x, escalados en y al rango [min, max]
  def self.puntos(valores, ancho:, alto:, min: nil, max: nil)
    return [] if valores.empty?

    min ||= valores.min
    max ||= valores.max
    paso = valores.size > 1 ? (ancho - (2 * MARGEN)).fdiv(valores.size - 1) : 0

    valores.each_with_index.map do |valor, indice|
      [ (MARGEN + (indice * paso)).round(1), y_para(valor, alto:, min:, max:) ]
    end
  end

  # Coordenada vertical de un valor dentro del alto disponible
  def self.y_para(valor, alto:, min:, max:)
    rango = (max - min).to_f
    rango = 1.0 if rango.zero?
    (alto - MARGEN - (((valor - min) / rango) * (alto - (2 * MARGEN)))).round(1)
  end

  # Path SVG suavizado (Catmull-Rom → Bézier) para líneas de tendencia
  def self.camino_suave(puntos)
    return "" if puntos.empty?

    camino = "M #{puntos[0][0]},#{puntos[0][1]}"
    return camino if puntos.size < 2

    (0...(puntos.size - 1)).each do |i|
      p0 = puntos[[ i - 1, 0 ].max]
      p1 = puntos[i]
      p2 = puntos[i + 1]
      p3 = puntos[[ i + 2, puntos.size - 1 ].min]

      c1x = (p1[0] + ((p2[0] - p0[0]) / 6.0)).round(1)
      c1y = (p1[1] + ((p2[1] - p0[1]) / 6.0)).round(1)
      c2x = (p2[0] - ((p3[0] - p1[0]) / 6.0)).round(1)
      c2y = (p2[1] - ((p3[1] - p1[1]) / 6.0)).round(1)
      camino += " C #{c1x},#{c1y} #{c2x},#{c2y} #{p2[0]},#{p2[1]}"
    end
    camino
  end
end
