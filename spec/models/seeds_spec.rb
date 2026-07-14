require "rails_helper"

# Permite componer "no cambia X y tampoco Y" con .and (change no se puede
# negar dentro de una cadena compuesta sin esto).
RSpec::Matchers.define_negated_matcher :not_change, :change

# El seed de arranque de tenant (db/seeds.rb) promete idempotencia: correrlo
# N veces sobre cualquier base no duplica ni pisa datos editados por el staff.
# Aquí se verifica, no se asume (SDD §16).
RSpec.describe "db/seeds.rb (arranque de tenant)", type: :model do
  def correr_seed
    load Rails.root.join("db/seeds.rb")
  end

  it "siembra admin, planes y bibliotecas, y es idempotente al correr dos veces" do
    correr_seed

    admin = User.find_by(email_address: "admin@advancefitness.local")
    expect(admin).to be_present
    expect(admin.admin?).to be_truthy
    expect(Plan.exists?(codigo: "free")).to be_truthy
    expect(Plan.exists?(codigo: "personalizado")).to be_truthy
    expect(Plan.find_by(codigo: "personalizado").precio.to_i).to eq(Negocio.precio_personalizado)
    expect(PlantillaComida.count).to be >= 20
    expect(PlantillaEjercicio.count).to be >= 33

    expect { correr_seed }.to not_change(User, :count)
      .and not_change(Plan, :count)
      .and not_change(PlantillaComida, :count)
      .and not_change(PlantillaEjercicio, :count)
  end

  it "no pisa las ediciones del staff sobre una plantilla sembrada" do
    correr_seed
    plantilla = PlantillaComida.find_by!(nombre: "Huevos con arepa")
    plantilla.update!(kcal: 999)

    correr_seed

    expect(plantilla.reload.kcal).to eq(999)
  end

  it "vincula plantillas al catálogo visual solo cuando existe el ejercicio" do
    correr_seed
    press = PlantillaEjercicio.find_by!(nombre: "Press de banca con barra")
    expect(press.ejercicio_id).to be_nil # catálogo aún vacío en esta base

    Ejercicio.create!(dataset_id: "0025", nombre: "Press de banca con barra",
                      nombre_en: "barbell bench press", musculo: "pecho", categoria: "chest")
    correr_seed

    expect(press.reload.ejercicio_id).to be_present
  end
end
