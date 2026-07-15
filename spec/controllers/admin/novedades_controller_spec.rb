require "rails_helper"

RSpec.describe "Admin::Novedades", type: :request do
  it "un miembro no accede" do
    sign_in_as users(:one)
    get admin_novedades_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador crea una novedad" do
    sign_in_as users(:entrenador)

    expect {
      post admin_novedades_path, params: { novedad: { titulo: "Clase especial", contenido: "Este sábado", publicado: true } }
    }.to change(Novedad, :count).by(1)

    expect(Novedad.last.publicado?).to be true
  end
end
