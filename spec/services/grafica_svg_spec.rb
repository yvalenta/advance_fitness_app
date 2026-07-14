require "rails_helper"

RSpec.describe GraficaSvg, type: :model do
  it "distribuye los puntos en x y escala en y" do
    puntos = GraficaSvg.puntos([ 70, 75, 80 ], ancho: 600, alto: 200)

    expect(puntos.size).to eq(3)
    expect(puntos.first[0]).to eq(GraficaSvg::MARGEN)
    expect(puntos.last[0]).to eq(600 - GraficaSvg::MARGEN)
    expect(puntos.first[1]).to eq(200 - GraficaSvg::MARGEN)   # mínimo abajo
    expect(puntos.last[1]).to eq(GraficaSvg::MARGEN)          # máximo arriba
  end

  it "serie constante no divide por cero" do
    puntos = GraficaSvg.puntos([ 70, 70 ], ancho: 600, alto: 200)

    expect(puntos.size).to eq(2)
    expect(puntos.all? { |_, y| y.between?(0, 200) }).to be_truthy
  end

  it "serie vacía devuelve lista vacía" do
    expect(GraficaSvg.puntos([], ancho: 600, alto: 200)).to be_empty
  end

  it "camino_suave genera un path Bézier que pasa por los extremos" do
    puntos = GraficaSvg.puntos([ 70, 75, 72 ], ancho: 600, alto: 200)
    camino = GraficaSvg.camino_suave(puntos)

    expect(camino.start_with?("M #{puntos.first[0]},#{puntos.first[1]}")).to be_truthy
    expect(camino.end_with?("#{puntos.last[0]},#{puntos.last[1]}")).to be_truthy
    expect(camino.scan(" C ").size).to eq(2)   # un segmento cúbico por tramo
    expect(GraficaSvg.camino_suave([])).to eq("")
  end

  it "y_para respeta un rango explícito (barras desde cero)" do
    base = GraficaSvg.y_para(0, alto: 200, min: 0, max: 100)
    tope = GraficaSvg.y_para(100, alto: 200, min: 0, max: 100)

    expect(base).to eq(200 - GraficaSvg::MARGEN)
    expect(tope).to eq(GraficaSvg::MARGEN)
    expect(GraficaSvg.y_para(50, alto: 200, min: 0, max: 100).between?(tope, base)).to be_truthy
  end
end
