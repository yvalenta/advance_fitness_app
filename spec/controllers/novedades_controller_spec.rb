require "rails_helper"

# Regresión (Fase de Calidad): la Fase 8 dejó el controller y el link del
# navbar sin la vista pública — /novedades reventaba con MissingExactTemplate.
# Fase 18f: además, el listado pasa por policy_scope — solo el tenant propio.
RSpec.describe "Novedades públicas", type: :request do
  it "un miembro ve solo las novedades publicadas" do
    publicada = Novedad.create!(titulo: "Clase de yoga", contenido: "Sábado 9am",
                                publicado: true, tenant: tenants(:advance_fitness))
    Novedad.create!(titulo: "Borrador interno", contenido: "x", tenant: tenants(:advance_fitness))
    sign_in_as users(:one)

    get novedades_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(publicada.titulo)
    expect(response.body).not_to include("Borrador interno")
  end

  it "no muestra novedades de otro tenant aunque estén publicadas" do
    Novedad.create!(titulo: "Promo ajena", contenido: "x",
                    publicado: true, tenant: tenants(:megaplex))
    sign_in_as users(:one)

    get novedades_path

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include("Promo ajena")
  end
end
