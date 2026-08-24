require "rails_helper"

RSpec.describe "ReprogramacionesDia", type: :request do
  let(:lunes) { Date.current.beginning_of_week }
  let(:rutina) do
    { "dias" => [
      { "dia" => "lunes", "enfoque" => "Empuje", "ejercicios" => [ { "uid" => "u1", "nombre" => "Press banca", "series" => 3, "repeticiones" => "10" } ] },
      { "dia" => "miercoles", "enfoque" => "Piernas", "ejercicios" => [ { "uid" => "u2", "nombre" => "Sentadilla", "series" => 3, "repeticiones" => "10" } ] }
    ] }
  end

  def crear_plan!(user, rutina:)
    PlanPersonalizado.create!(user: user, generado_por: "reglas", estado: "aprobado", rutina: rutina, plan_nutricional: {})
  end

  describe "POST /reprogramaciones_dia" do
    it "mueve el entrenamiento y redirige a la fecha original con el aviso" do
      crear_plan!(users(:one), rutina: rutina)
      sign_in_as users(:one)

      expect do
        post reprogramaciones_dia_path, params: { fecha_original: lunes.iso8601, fecha_destino: (lunes + 3).iso8601 }
      end.to change(ReprogramacionDia, :count).by(1)

      expect(response).to redirect_to(sesion_path(lunes.iso8601))
      r = ReprogramacionDia.last
      expect(r.fecha_original).to eq(lunes)
      expect(r.fecha_destino).to eq(lunes + 3)
    end

    it "reintentar con el mismo origen actualiza el destino (upsert), no duplica" do
      plan = crear_plan!(users(:one), rutina: rutina)
      plan.reprogramaciones_dia.create!(fecha_original: lunes, fecha_destino: lunes + 3)
      sign_in_as users(:one)

      expect do
        post reprogramaciones_dia_path, params: { fecha_original: lunes.iso8601, fecha_destino: (lunes + 5).iso8601 }
      end.not_to change(ReprogramacionDia, :count)

      expect(plan.reprogramaciones_dia.first.fecha_destino).to eq(lunes + 5)
    end

    it "un destino inválido (igual al origen) no crea nada y avisa" do
      crear_plan!(users(:one), rutina: rutina)
      sign_in_as users(:one)

      expect do
        post reprogramaciones_dia_path, params: { fecha_original: lunes.iso8601, fecha_destino: lunes.iso8601 }
      end.not_to change(ReprogramacionDia, :count)
      expect(flash[:alert]).to be_present
    end

    it "sin plan aprobado no crea nada" do
      sign_in_as users(:one)

      expect do
        post reprogramaciones_dia_path, params: { fecha_original: lunes.iso8601, fecha_destino: (lunes + 1).iso8601 }
      end.not_to change(ReprogramacionDia, :count)
      expect(response).to redirect_to(sesion_path)
    end

    it "no se puede reprogramar el plan de otro miembro" do
      plan_ajeno = crear_plan!(users(:two), rutina: rutina)
      sign_in_as users(:one)

      expect do
        post reprogramaciones_dia_path, params: { fecha_original: lunes.iso8601, fecha_destino: (lunes + 1).iso8601 }
      end.not_to change(ReprogramacionDia, :count)
      expect(plan_ajeno.reprogramaciones_dia).to be_empty
    end
  end

  describe "DELETE /reprogramaciones_dia/:id" do
    it "el dueño puede deshacer su propia reprogramación" do
      plan = crear_plan!(users(:one), rutina: rutina)
      r = plan.reprogramaciones_dia.create!(fecha_original: lunes, fecha_destino: lunes + 3)
      sign_in_as users(:one)

      expect { delete reprogramacion_dia_path(r) }.to change(ReprogramacionDia, :count).by(-1)
      expect(response).to redirect_to(sesion_path(lunes.iso8601))
    end

    it "otro miembro no puede deshacer una reprogramación ajena (ni la ve entre las suyas)" do
      crear_plan!(users(:one), rutina: rutina) # users(:one) también tiene plan propio
      plan_ajeno = crear_plan!(users(:two), rutina: rutina)
      r = plan_ajeno.reprogramaciones_dia.create!(fecha_original: lunes, fecha_destino: lunes + 3)
      sign_in_as users(:one)

      expect { delete reprogramacion_dia_path(r) }.not_to change(ReprogramacionDia, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "en /sesion" do
    it "el día original queda sin contenido y ofrece ir a la nueva fecha" do
      plan = crear_plan!(users(:one), rutina: rutina)
      plan.reprogramaciones_dia.create!(fecha_original: lunes, fecha_destino: lunes + 3)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)
      expect(response.body).to include("Este entrenamiento se movió")
      expect(response.body).not_to include("Press banca")
    end

    it "la fecha destino muestra el contenido movido con aviso y opción de deshacer" do
      plan = crear_plan!(users(:one), rutina: rutina)
      plan.reprogramaciones_dia.create!(fecha_original: lunes, fecha_destino: lunes + 3)
      sign_in_as users(:one)

      get sesion_path((lunes + 3).iso8601)
      expect(response.body).to include("Press banca") # contenido del lunes, movido aquí
      expect(response.body).to include("movido aquí")
      expect(response.body).not_to include("¿No puedes hoy?") # no se ofrece reprogramar un día ya movido
    end

    it "un día sin reprogramar sí ofrece la opción de moverlo" do
      crear_plan!(users(:one), rutina: rutina)
      sign_in_as users(:one)

      get sesion_path(lunes.iso8601)
      expect(response.body).to include("¿No puedes hoy?")
    end
  end
end
