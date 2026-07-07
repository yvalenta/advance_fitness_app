require "test_helper"

class GraficaSvgTest < ActiveSupport::TestCase
  test "distribuye los puntos en x y escala en y" do
    puntos = GraficaSvg.puntos([ 70, 75, 80 ], ancho: 600, alto: 200)

    assert_equal 3, puntos.size
    assert_equal GraficaSvg::MARGEN, puntos.first[0]
    assert_equal 600 - GraficaSvg::MARGEN, puntos.last[0]
    assert_equal 200 - GraficaSvg::MARGEN, puntos.first[1]   # mínimo abajo
    assert_equal GraficaSvg::MARGEN, puntos.last[1]          # máximo arriba
  end

  test "serie constante no divide por cero" do
    puntos = GraficaSvg.puntos([ 70, 70 ], ancho: 600, alto: 200)

    assert_equal 2, puntos.size
    assert puntos.all? { |_, y| y.between?(0, 200) }
  end

  test "serie vacía devuelve lista vacía" do
    assert_empty GraficaSvg.puntos([], ancho: 600, alto: 200)
  end

  test "camino_suave genera un path Bézier que pasa por los extremos" do
    puntos = GraficaSvg.puntos([ 70, 75, 72 ], ancho: 600, alto: 200)
    camino = GraficaSvg.camino_suave(puntos)

    assert camino.start_with?("M #{puntos.first[0]},#{puntos.first[1]}")
    assert camino.end_with?("#{puntos.last[0]},#{puntos.last[1]}")
    assert_equal 2, camino.scan(" C ").size   # un segmento cúbico por tramo
    assert_equal "", GraficaSvg.camino_suave([])
  end

  test "y_para respeta un rango explícito (barras desde cero)" do
    base = GraficaSvg.y_para(0, alto: 200, min: 0, max: 100)
    tope = GraficaSvg.y_para(100, alto: 200, min: 0, max: 100)

    assert_equal 200 - GraficaSvg::MARGEN, base
    assert_equal GraficaSvg::MARGEN, tope
    assert GraficaSvg.y_para(50, alto: 200, min: 0, max: 100).between?(tope, base)
  end
end
