require "rails_helper"

RSpec.describe Rutina::Resolutor do
  def ejercicio_base
    { "uid" => "u-press", "nombre" => "Press banca", "series" => 4, "repeticiones" => "8-10",
      "descanso_seg" => 90, "peso_sugerido_kg" => 60, "ejercicio_id" => 7,
      "nota_tecnica" => "Escápulas retraídas" }
  end

  def dias_base
    [ { "dia" => "lunes", "enfoque" => "pecho", "ejercicios" => [ ejercicio_base ] } ]
  end

  def rutina_v2(ajuste_semana2: { "series_delta" => 1, "peso_factor" => 1.1, "reps_delta" => 1 })
    { "version" => 2,
      "mesociclo" => { "nombre" => "Base", "semanas_total" => 2, "inicio" => "2026-08-03", "progresion" => "lineal" },
      "dias" => dias_base,
      "semanas" => [
        { "numero" => 1, "etiqueta" => "Adaptación", "descarga" => false,
          "ajuste" => { "series_delta" => 0, "peso_factor" => 1.0, "reps_delta" => 0 }, "dias" => nil },
        { "numero" => 2, "etiqueta" => "Carga", "descarga" => false,
          "ajuste" => ajuste_semana2, "dias" => nil }
      ] }
  end

  describe ".aplicar_ajuste" do
    it "suma series_delta con piso 1" do
      subida = described_class.aplicar_ajuste(dias_base, { "series_delta" => 2 })
      expect(subida.first["ejercicios"].first["series"]).to eq(6)

      bajada = described_class.aplicar_ajuste(dias_base, { "series_delta" => -2 })
      hundida = described_class.aplicar_ajuste(
        [ { "ejercicios" => [ { "series" => 1 } ] } ], { "series_delta" => -2 }
      )
      expect(bajada.first["ejercicios"].first["series"]).to eq(2)
      expect(hundida.first["ejercicios"].first["series"]).to eq(1)
    end

    it "multiplica el peso por el factor redondeando a medios kilos, enteros sin .0" do
      ej = described_class.aplicar_ajuste(dias_base, { "peso_factor" => 1.1 }).first["ejercicios"].first
      expect(ej["peso_sugerido_kg"]).to eq(66) # 60 × 1.1 = 66.0 → entero

      con_medio = described_class.aplicar_ajuste(
        [ { "ejercicios" => [ { "peso_sugerido_kg" => 22.5 } ] } ], { "peso_factor" => 0.9 }
      ).first["ejercicios"].first
      expect(con_medio["peso_sugerido_kg"]).to eq(20.5) # 20.25 → medio kilo más cercano (empate arriba)
    end

    it "sin peso_sugerido_kg no inventa la clave" do
      ej = described_class.aplicar_ajuste(
        [ { "ejercicios" => [ { "nombre" => "Plancha", "series" => 3 } ] } ], { "peso_factor" => 1.2 }
      ).first["ejercicios"].first
      expect(ej).not_to have_key("peso_sugerido_kg")
    end

    it "desplaza ambos extremos de un rango de repeticiones con piso 1" do
      ej = described_class.aplicar_ajuste(dias_base, { "reps_delta" => 2 }).first["ejercicios"].first
      expect(ej["repeticiones"]).to eq("10-12")

      piso = described_class.aplicar_ajuste(
        [ { "ejercicios" => [ { "repeticiones" => "1-3" } ] } ], { "reps_delta" => -2 }
      ).first["ejercicios"].first
      expect(piso["repeticiones"]).to eq("1-1")
    end

    it "acepta rangos con espacios y deja intacto el texto libre" do
      dias = [ { "ejercicios" => [
        { "repeticiones" => "8 - 10" }, { "repeticiones" => "al fallo" },
        { "repeticiones" => "12" }, { "repeticiones" => "3x10" }
      ] } ]
      reps = described_class.aplicar_ajuste(dias, { "reps_delta" => 1 })
               .first["ejercicios"].map { |ej| ej["repeticiones"] }
      expect(reps).to eq([ "9-11", "al fallo", "12", "3x10" ])
    end

    it "en identidad deja cada campo EXACTO (ni siquiera normaliza el formato)" do
      dias = [ { "ejercicios" => [ { "series" => 0, "repeticiones" => "8 - 10", "peso_sugerido_kg" => 22.5 } ] } ]
      ej = described_class.aplicar_ajuste(dias, nil).first["ejercicios"].first
      expect(ej).to eq({ "series" => 0, "repeticiones" => "8 - 10", "peso_sugerido_kg" => 22.5 })
    end

    it "jamás toca uid, nombre, ejercicio_id, nota_tecnica ni descanso_seg" do
      ej = described_class.aplicar_ajuste(
        dias_base, { "series_delta" => 2, "peso_factor" => 0.8, "reps_delta" => -1 }
      ).first["ejercicios"].first

      expect(ej.slice("uid", "nombre", "ejercicio_id", "nota_tecnica", "descanso_seg"))
        .to eq(ejercicio_base.slice("uid", "nombre", "ejercicio_id", "nota_tecnica", "descanso_seg"))
    end

    it "no muta la entrada y devuelve copias independientes" do
      entrada = dias_base
      resultado = described_class.aplicar_ajuste(entrada, { "series_delta" => 1 })

      expect(entrada.first["ejercicios"].first["series"]).to eq(4)
      resultado.first["ejercicios"].first["nombre"] = "Otro"
      expect(entrada.first["ejercicios"].first["nombre"]).to eq("Press banca")
    end
  end

  describe ".componer" do
    it "suma deltas y multiplica factores" do
      compuesto = described_class.componer(
        { "series_delta" => 1, "peso_factor" => 1.1, "reps_delta" => -1 },
        { "series_delta" => -2, "peso_factor" => 1.05, "reps_delta" => 1 }
      )
      expect(compuesto).to eq({ "series_delta" => -1, "reps_delta" => 0, "peso_factor" => 1.155 })
    end

    it "aplica el clamp final del factor a 0.7..1.25" do
      alto = described_class.componer({ "peso_factor" => 1.2 }, { "peso_factor" => 1.15 })
      bajo = described_class.componer({ "peso_factor" => 0.8 }, { "peso_factor" => 0.8 })
      expect(alto["peso_factor"]).to eq(1.25) # 1.38 recortado
      expect(bajo["peso_factor"]).to eq(0.7)  # 0.64 recortado
    end

    it "trata nil como identidad" do
      expect(described_class.componer(nil, nil))
        .to eq({ "series_delta" => 0, "reps_delta" => 0, "peso_factor" => 1.0 })
    end
  end

  describe ".dias" do
    it "una semana heredada aplica su ajuste sobre la base" do
      ej = described_class.dias(rutina_v2, 2).first["ejercicios"].first
      expect(ej["series"]).to eq(5)               # 4 + 1
      expect(ej["peso_sugerido_kg"]).to eq(66)    # 60 × 1.1
      expect(ej["repeticiones"]).to eq("9-11")    # 8-10 desplazado
      expect(ej["uid"]).to eq("u-press")          # mismo ejercicio
    end

    it "la semana identidad devuelve la base sin cambios" do
      expect(described_class.dias(rutina_v2, 1)).to eq(dias_base)
    end

    it "una semana materializada es la verdad tal cual (su ajuste no se reaplica)" do
      rutina = rutina_v2
      rutina["semanas"][1]["dias"] = [ { "dia" => "lunes", "ejercicios" => [
        { "uid" => "u-press", "nombre" => "Press banca", "series" => 9, "repeticiones" => "6-8" }
      ] } ]

      ej = described_class.dias(rutina, 2).first["ejercicios"].first
      expect(ej["series"]).to eq(9)
      expect(ej["repeticiones"]).to eq("6-8")
    end

    it "compone el ajuste extra con el de la semana heredada, con clamp" do
      ej = described_class.dias(rutina_v2, 2, extra: { "peso_factor" => 1.2, "series_delta" => 1 })
             .first["ejercicios"].first
      expect(ej["series"]).to eq(6)             # 4 + 1 + 1
      expect(ej["peso_sugerido_kg"]).to eq(75)  # 60 × clamp(1.1 × 1.2 → 1.25)
    end

    it "sobre una semana materializada el extra se aplica pasando por el clamp" do
      rutina = rutina_v2
      rutina["semanas"][1]["dias"] = [ { "ejercicios" => [ { "peso_sugerido_kg" => 100 } ] } ]

      ej = described_class.dias(rutina, 2, extra: { "peso_factor" => 0.5 }).first["ejercicios"].first
      expect(ej["peso_sugerido_kg"]).to eq(70) # clamp a 0.7, no 0.5
    end

    it "una rutina v1 o una semana desconocida devuelven la base (identidad)" do
      v1 = { "dias" => dias_base }
      expect(described_class.dias(v1, 1)).to eq(dias_base)
      expect(described_class.dias(rutina_v2, 9)).to eq(dias_base)
    end

    it "devuelve copias: mutar el resultado no toca la rutina" do
      rutina = rutina_v2
      described_class.dias(rutina, 1).first["ejercicios"] << { "nombre" => "Intruso" }
      expect(rutina["dias"].first["ejercicios"].size).to eq(1)
    end
  end
end
