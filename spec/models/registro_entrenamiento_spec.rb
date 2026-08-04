require "rails_helper"

RSpec.describe RegistroEntrenamiento, type: :model do
  def crear_registro(ejercicios = {})
    users(:one).registros_entrenamiento.create!(fecha: Date.current, ejercicios: ejercicios)
  end

  # Estado v1 típico (pre-Fase 14.6): clave = índice posicional.
  def v1_con_press
    { "0" => { "hecho" => true, "nota" => "banca 4", "nombre" => "Press banca" },
      "2" => { "hecho" => false, "nombre" => "Sentadilla" },
      "novedad" => "hombro resentido" }
  end

  # Fase 14.6: ajustado a la firma nueva de marcar!/estado_de (antes era
  # posicional); misma conducta que probaba: guarda estado + strip de la nota
  # y no pisa otros ejercicios.
  it "marcar! guarda estado por uid y preserva otros ejercicios" do
    registro = crear_registro

    registro.marcar!(uid: "uidpress01", hecho: true, nota: " subí peso ", nombre: "Press banca", dia: 0, indice: 0)
    registro.marcar!(uid: "uidsenta02", hecho: false, nota: "", nombre: "Sentadilla", dia: 0, indice: 2)

    expect(registro.reload.estado_de(uid: "uidpress01")["hecho"]).to eq(true)
    expect(registro.estado_de(uid: "uidpress01")["nota"]).to eq("subí peso")     # strip
    expect(registro.estado_de(uid: "uidpress01")["nombre"]).to eq("Press banca")
    expect(registro.estado_de(uid: "uidsenta02")["hecho"]).to eq(false)
  end

  # Fase 14.6: ajustado a la firma nueva (antes "sobre el mismo índice").
  it "marcar! sobre el mismo uid reemplaza su estado" do
    registro = crear_registro
    registro.marcar!(uid: "uidpress01", hecho: true, nota: "a", nombre: "Press", dia: 0, indice: 0)
    registro.marcar!(uid: "uidpress01", hecho: false, nota: "b", nombre: "Press", dia: 0, indice: 0)

    expect(registro.reload.estado_de(uid: "uidpress01")["hecho"]).to eq(false)
    expect(registro.estado_de(uid: "uidpress01")["nota"]).to eq("b")
  end

  # Fase 14.6: ajustado a la firma nueva de estado_de (keywords).
  it "estado_de de un ejercicio sin marcar es vacío" do
    registro = users(:one).registros_entrenamiento.new(fecha: Date.current)
    expect(registro.estado_de(indice: 5)).to eq({})
    expect(registro.estado_de(uid: "uidfantasm")).to eq({})
  end

  # Fase 14.6: ajustado a la firma nueva de marcar!/estado_de.
  it "la novedad del día convive con los checks (Fase 5.11)" do
    registro = crear_registro
    registro.marcar!(uid: "uidpress01", hecho: true, nombre: "Press", dia: 0, indice: 0)
    registro.marcar_novedad!("  rodilla resentida  ")

    expect(registro.reload.novedad).to eq("rodilla resentida")
    expect(registro.estado_de(uid: "uidpress01")["hecho"]).to eq(true)
  end

  it "una fila por usuario y fecha" do
    users(:one).registros_entrenamiento.create!(fecha: Date.current)
    repetido = users(:one).registros_entrenamiento.new(fecha: Date.current)

    expect(repetido.valid?).to be_falsey
    expect(repetido.errors[:fecha].any?).to be_truthy
  end

  # ── Formato v2 anclado por uid (Fase 14.6) ─────────────────────────────

  it "marcar! escribe v2 con dia/indice como metadato histórico y plan_id" do
    registro = crear_registro
    registro.marcar!(uid: "uidpress01", hecho: true, nombre: "Press banca",
                     dia: 3, indice: 2, plan_id: 42)

    datos = registro.reload.ejercicios
    expect(datos["version"]).to eq(2)
    expect(datos["plan_id"]).to eq(42)
    expect(datos.dig("items", "uidpress01")).to include("hecho" => true, "dia" => 3, "indice" => 2)
  end

  it "un registro v1 se sigue leyendo intacto por índice" do
    registro = crear_registro(v1_con_press)

    expect(registro.estado_de(indice: 0)["hecho"]).to eq(true)
    expect(registro.estado_de(indice: 2)["nombre"]).to eq("Sentadilla")
    # Con uid desconocido cae al índice porque el registro NO tiene "version"
    expect(registro.estado_de(uid: "uidpress01", indice: 0)["hecho"]).to eq(true)
    expect(registro.novedad).to eq("hombro resentido")
  end

  it "marcar! sobre un v1 estrena items y archiva las claves numéricas bajo legacy" do
    registro = crear_registro(v1_con_press)
    registro.marcar!(uid: "uidsenta02", hecho: true, nombre: "Sentadilla", dia: 0, indice: 2)

    datos = registro.reload.ejercicios
    expect(datos["version"]).to eq(2)
    expect(datos.dig("items", "uidsenta02")["hecho"]).to eq(true)
    expect(datos.dig("legacy", "0")).to eq("hecho" => true, "nota" => "banca 4", "nombre" => "Press banca")
    expect(datos.dig("legacy", "2", "nombre")).to eq("Sentadilla")
    expect(datos.keys).not_to include("0", "2")          # nada posicional suelto
    expect(registro.novedad).to eq("hombro resentido")   # la novedad sobrevive
  end

  it "re-marcar sin nota conserva la nota escrita en la era v1" do
    registro = crear_registro(v1_con_press)
    registro.marcar!(uid: "uidpress01", hecho: false, nombre: "Press banca", dia: 0, indice: 0)

    expect(registro.reload.estado_de(uid: "uidpress01")["nota"]).to eq("banca 4")
  end

  it "el fallback por índice aplica SOLO a registros sin version" do
    registro = crear_registro
    registro.marcar!(uid: "uidpress01", hecho: true, nombre: "Press banca", dia: 0, indice: 0)

    # v2: un uid desconocido NO cae al índice aunque haya item con ese indice
    expect(registro.reload.estado_de(uid: "uidotro999", indice: 0)).to eq({})
  end

  it "sin uid (plan previo a Fase 14.6) ancla posicional bajo clave sintética" do
    registro = crear_registro
    registro.marcar!(uid: "", hecho: true, nombre: "Press banca", dia: 0, indice: 3)

    expect(registro.reload.ejercicios.dig("items", "i3")["hecho"]).to eq(true)
    expect(registro.estado_de(uid: "", indice: 3)["hecho"]).to eq(true)
    expect(registro.estado_de(indice: 3)["hecho"]).to eq(true)
  end
end
