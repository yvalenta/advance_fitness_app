require "rails_helper"

# Fase 14.9 — CONTRATO del mesociclo sobre un plan v1 (rutina sin "version"):
# se comporta como mesociclo de 1 semana identidad. Estas expectativas son del
# contrato acordado con 14.7, no del placeholder: deben seguir en verde cuando
# MesocicloPlaceholder sea reemplazado por la implementación real.
RSpec.describe "Contrato del mesociclo (plan v1 identidad)", type: :model do
  let(:rutina) do
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "Pecho", "ejercicios" => [
        { "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10", "descanso_seg" => 90 }
      ] },
      { "dia" => "martes", "enfoque" => "Pierna", "ejercicios" => [] }
    ] }
  end

  let(:plan) do
    PlanPersonalizado.create!(user: users(:one), generado_por: "reglas",
                              estado: "aprobado", rutina: rutina, plan_nutricional: {})
  end

  it "es un mesociclo de una sola semana identidad" do
    expect(plan.semanas.size).to eq(1)

    semana = plan.semanas.first
    expect(semana["numero"]).to eq(1)
    expect(semana["etiqueta"]).to be_present
    expect(semana["descarga"]).to be_falsey
    expect(semana["dias"]).to eq(plan.dias)

    expect(plan.semana(1)).to eq(semana)
    expect(plan.semana_actual).to eq(1)
    expect(plan.dias(semana: 1)).to eq(plan.dias)
    expect(plan.semana_materializada?(1)).to be_falsey
    expect(plan.mesociclo_completado?).to be_falsey
  end

  it "dias sin argumento conserva el contrato histórico (días base de la rutina)" do
    expect(plan.dias).to eq(rutina["dias"])
  end

  it "Rutina::Calendario ancla la semana 1 de un plan v1 a la semana calendario actual" do
    lunes = Date.current.beginning_of_week

    expect(Rutina::Calendario.fecha_de(plan, semana: 1, dia_indice: 0)).to eq(lunes)      # lunes
    expect(Rutina::Calendario.fecha_de(plan, semana: 1, dia_indice: 1)).to eq(lunes + 1)  # martes
  end
end
