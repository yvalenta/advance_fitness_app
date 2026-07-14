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
end
