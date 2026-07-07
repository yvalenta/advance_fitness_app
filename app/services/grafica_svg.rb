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
end
