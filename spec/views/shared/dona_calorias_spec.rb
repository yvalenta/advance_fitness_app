require "rails_helper"

# Dona de calorías (Fase 14.4) — interfaz FIJA del partial compartido:
# locals (consumidas:, objetivo:, quemadas: nil, macros: nil).
# Restantes = objetivo − consumidas + quemadas, clamp visual en 0.
RSpec.describe "shared/_dona_calorias", type: :view do
  def dona(**locals)
    render partial: "shared/dona_calorias", locals: { consumidas: 0, objetivo: 2000 }.merge(locals)
    rendered
  end

  it "muestra restantes = objetivo − consumidas junto a las consumidas" do
    html = dona(consumidas: 1200, objetivo: 2000)

    expect(html).to include("Restantes")
    expect(html).to include("Consumidas")
    expect(html).to match(/>\s*800\s*</) # 2000 − 1200
  end

  it "sin quemadas oculta ese lado de la dona" do
    expect(dona(consumidas: 100)).not_to include("Quemadas")
  end

  it "las quemadas amplían el presupuesto del día" do
    html = dona(consumidas: 2000, objetivo: 1800, quemadas: 400)

    expect(html).to include("Quemadas")
    expect(html).to include("400")
    expect(html).to match(/>\s*200\s*</) # 1800 − 2000 + 400
  end

  it "excedido clampa el restante en 0 y enciende el estado pulse" do
    html = dona(consumidas: 2500, objetivo: 2000)

    expect(html).to include("Excedido")
    expect(html).to include("animate-pulse")
    expect(html).to match(/>\s*0\s*</)      # el restante visual nunca es negativo
    expect(html).to include("+500")          # pero el exceso sí se comunica
    expect(html).not_to include("grafica-linea") # el anillo pulsa, no se "dibuja"
  end

  it "con macros pinta las tres mini-barras consumido/objetivo" do
    html = dona(consumidas: 1200,
                macros: { proteinas: [ 67, 132 ], carbohidratos: [ 104, 238 ], grasas: [ 65, 70 ] })

    expect(html).to include("Proteína", "Carbohidratos", "Grasas")
    expect(html).to include("67/132g", "104/238g", "65/70g")
  end

  it "sin macros no hay mini-barras" do
    expect(dona).not_to include("Carbohidratos")
  end
end
