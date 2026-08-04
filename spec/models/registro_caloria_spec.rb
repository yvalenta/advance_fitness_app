require "rails_helper"

RSpec.describe RegistroCaloria, type: :model do
  it "registrar crea el registro del día" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1800)

    expect(registro.persisted?).to be_truthy
    expect(registro.fecha).to eq(Date.current)
    expect(registro.kcal_consumidas).to eq(1800)
  end

  it "registrar el mismo día reemplaza el total (upsert, no duplica)" do
    RegistroCaloria.registrar(users(:one), kcal: 1200)

    expect {
      RegistroCaloria.registrar(users(:one), kcal: 1750)
    }.not_to change(RegistroCaloria, :count)
    expect(users(:one).registros_calorias.find_by(fecha: Date.current).kcal_consumidas).to eq(1750)
  end

  it "kcal negativas no se guardan" do
    registro = RegistroCaloria.registrar(users(:one), kcal: -100)

    expect(registro.persisted?).to be_falsey
  end

  # Fase 5.8: el miembro puede anotar qué comió por comida (kcal + nota).
  it "registrar guarda el detalle de lo que comió el miembro" do
    detalle = { "comidas" => [ { "nombre" => "Desayuno", "kcal" => 300, "nota" => "cambié arroz por quinoa" } ] }
    registro = RegistroCaloria.registrar(users(:one), kcal: 300, detalle: detalle)

    expect(registro.persisted?).to be_truthy
    expect(registro.reload.detalle).to eq(detalle)
  end

  it "registrar sin detalle deja el detalle por defecto vacío" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1500)

    expect(registro.reload.detalle).to eq({})
  end

  # Fase 14.4: el consumo real guarda también los macros (gramos) cuando llegan.
  it "registrar guarda los macros del consumo" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1800,
                                         proteinas_g: 90, carbohidratos_g: 180, grasas_g: 55)

    registro.reload
    expect([ registro.proteinas_g, registro.carbohidratos_g, registro.grasas_g ]).to eq([ 90, 180, 55 ])
  end

  it "reenviar solo kcal no borra los macros ya anotados del día" do
    RegistroCaloria.registrar(users(:one), kcal: 1800, proteinas_g: 90, carbohidratos_g: 180, grasas_g: 55)

    registro = RegistroCaloria.registrar(users(:one), kcal: 2000)

    expect(registro.reload.proteinas_g).to eq(90)
    expect(registro.kcal_consumidas).to eq(2000)
  end

  it "macros negativos no se guardan" do
    registro = RegistroCaloria.registrar(users(:one), kcal: 1500, proteinas_g: -5)

    expect(registro.persisted?).to be_falsey
  end

  # Fase 14.4: la migración de macros es add_column puro — reversible.
  it "la migración de macros es reversible" do
    require Rails.root.glob("db/migrate/*_add_macros_a_registros_calorias.rb").first

    ActiveRecord::Migration.suppress_messages do
      AddMacrosARegistrosCalorias.new.migrate(:down)
      RegistroCaloria.reset_column_information
      expect(RegistroCaloria.column_names).not_to include("proteinas_g", "carbohidratos_g", "grasas_g")

      AddMacrosARegistrosCalorias.new.migrate(:up)
      RegistroCaloria.reset_column_information
      expect(RegistroCaloria.column_names).to include("proteinas_g", "carbohidratos_g", "grasas_g")
    end
  end
end
