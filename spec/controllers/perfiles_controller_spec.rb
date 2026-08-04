require "rails_helper"

RSpec.describe "Perfiles", type: :request do
  it "completa el perfil y redirige al objetivo" do
    sign_in_as users(:two)

    patch perfil_path, params: { user: {
      nombre: "Usuario Dos",
      fecha_nacimiento: "1998-05-10",
      sexo: "F",
      talla_cm: 162,
      nivel_actividad: 1.4
    } }

    expect(response).to redirect_to(objetivo_path)
    expect(users(:two).reload.perfil_nutricional_completo?).to be_truthy
  end

  it "el rol no es asignable desde el perfil" do
    sign_in_as users(:one)

    patch perfil_path, params: { user: { nombre: "Uno Actualizado", rol: "admin" } }

    expect(users(:one).reload.rol).to eq("miembro")
    expect(users(:one).reload.nombre).to eq("Uno Actualizado")
  end

  # Fase 16 (Nota 21): la preferencia de tema es del usuario y el SERVIDOR
  # renderiza el data-theme en el body — el redirect ya vuelve pintado.
  describe "preferencia de tema" do
    it "guardar 'claro' pinta el body con advance-claro en la siguiente página" do
      sign_in_as users(:one)

      patch perfil_path, params: { user: { tema: "claro" } }
      expect(users(:one).reload.tema).to eq("claro")

      get root_path
      expect(response.body).to match(/<body[^>]*data-theme="advance-claro"/)
    end

    it "'sistema' deja el body SIN data-theme (el SO decide vía CSS)" do
      users(:one).update!(tema: "sistema")
      sign_in_as users(:one)

      get root_path
      cuerpo = response.body[/<body[^>]*>/]
      expect(cuerpo).not_to include("data-theme")
    end

    it "el default es oscuro y un tema inválido no entra" do
      sign_in_as users(:one)

      get root_path
      expect(response.body).to match(/<body[^>]*data-theme="advance"/)

      patch perfil_path, params: { user: { tema: "fucsia" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(users(:one).reload.tema).to eq("oscuro")
    end
  end
end
