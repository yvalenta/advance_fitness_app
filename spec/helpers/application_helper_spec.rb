require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  # Fase 5.14: evita repetir el valor crudo de generado_por (y la palabra "IA")
  # en las vistas de staff.
  it "origen_plan traduce los tres generadores conocidos" do
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "ia"))).to eq("análisis automático")
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "reglas"))).to eq("plan de membresía")
    expect(helper.origen_plan(PlanPersonalizado.new(generado_por: "entrenador"))).to eq("entrenador")
  end

  # El beacon de analiticas. Lo que se protege es que NO aparezca donde no debe:
  # la inyeccion automatica de zona ya lo habia puesto en los ocho hostnames de
  # ynt.codes, incluido el verificador de sobres, que afirma no enviar nada a
  # ningun servidor. Acá es manual justamente para que su alcance sea decidido.
  describe "#beacon_analitica" do
    it "no renderiza nada sin token, aunque sea produccion" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CF_ANALYTICS_TOKEN").and_return(nil)
      expect(helper.beacon_analitica).to be_nil
    end

    it "tampoco con el token vacio — una variable puesta a '' es apagarlo" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CF_ANALYTICS_TOKEN").and_return("")
      expect(helper.beacon_analitica).to be_nil
    end

    # En desarrollo mediria el trafico de nadie y ensuciaria los datos reales.
    it "no renderiza fuera de produccion aunque haya token" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CF_ANALYTICS_TOKEN").and_return("abc123")
      expect(helper.beacon_analitica).to be_nil
    end

    it "en produccion y con token, emite el script con su token" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("CF_ANALYTICS_TOKEN").and_return("abc123")
      html = helper.beacon_analitica
      expect(html).to include("static.cloudflareinsights.com/beacon.min.js")
      expect(html).to include("abc123")
      # `defer` para que no compita con el render de la pagina.
      expect(html).to include("defer")
    end
  end
end
