require "rails_helper"

RSpec.describe ReprogramacionDia, type: :model do
  let(:plan) { PlanPersonalizado.create!(user: users(:one), generado_por: "reglas", estado: "aprobado", rutina: { "dias" => [] }, plan_nutricional: {}) }

  def reprogramacion(atributos = {})
    ReprogramacionDia.new({ plan_personalizado: plan, fecha_original: Date.current, fecha_destino: Date.current + 2 }.merge(atributos))
  end

  it "es válida con origen y destino distintos" do
    expect(reprogramacion).to be_valid
  end

  it "rechaza destino igual al origen" do
    expect(reprogramacion(fecha_destino: Date.current)).not_to be_valid
  end

  it "un origen solo puede moverse una vez (uniqueness por plan)" do
    reprogramacion.save!
    expect(reprogramacion(fecha_destino: Date.current + 5)).not_to be_valid
  end

  it "un destino solo puede recibir un origen (sin ambigüedad)" do
    reprogramacion.save!
    expect(reprogramacion(fecha_original: Date.current + 1, fecha_destino: Date.current + 2)).not_to be_valid
  end

  it "no encadena: el destino no puede ser ya el origen de otra reprogramación" do
    reprogramacion.save! # hoy → hoy+2
    # hoy+2 → hoy+4 encadenaría (hoy+2 ya es destino Y quedaría como origen)
    expect(reprogramacion(fecha_original: Date.current + 2, fecha_destino: Date.current + 4)).not_to be_valid
  end

  it "no encadena: el origen no puede ser ya el destino de otra reprogramación" do
    reprogramacion.save! # hoy → hoy+2
    expect(reprogramacion(fecha_original: Date.current + 2, fecha_destino: Date.current + 10)).not_to be_valid
  end

  it "actualizar el destino de la misma reprogramación (upsert) no choca consigo misma" do
    r = reprogramacion
    r.save!
    r.fecha_destino = Date.current + 9
    expect(r).to be_valid
  end

  it "se borra en cascada con el plan" do
    reprogramacion.save!
    expect { plan.destroy! }.to change(ReprogramacionDia, :count).by(-1)
  end
end
