require "rails_helper"

# Regresión (Fase de Calidad): la Fase 8 dejó el controller y el link del
# navbar sin la vista pública — /novedades reventaba con MissingExactTemplate.
RSpec.describe "Novedades públicas", type: :request do
  it "un miembro ve solo las novedades publicadas" do
    publicada = Novedad.create!(titulo: "Clase de yoga", contenido: "Sábado 9am", publicado: true)
    Novedad.create!(titulo: "Borrador interno", contenido: "x")
    sign_in_as users(:one)

    get novedades_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(publicada.titulo)
    expect(response.body).not_to include("Borrador interno")
  end
end
