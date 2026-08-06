require "rails_helper"

RSpec.describe "Admin::Novedades", type: :request do
  it "un miembro no accede" do
    sign_in_as users(:one)
    get admin_novedades_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador crea una novedad y queda en su tenant" do
    sign_in_as users(:entrenador)

    expect {
      post admin_novedades_path, params: { novedad: { titulo: "Clase especial", contenido: "Este sábado", publicado: true } }
    }.to change(Novedad, :count).by(1)

    expect(Novedad.last.publicado?).to be true
    # Fase 18f: sin tenant explícito la novedad nacía global (tenant_id nil)
    # y se filtraba a los miembros de todos los tenants.
    expect(Novedad.last.tenant).to eq(tenants(:advance_fitness))
  end

  it "el listado y la edición no alcanzan novedades de otro tenant" do
    ajena = Novedad.create!(titulo: "Promo ajena", contenido: "x",
                            publicado: true, tenant: tenants(:megaplex))
    sign_in_as users(:entrenador)

    get admin_novedades_path
    expect(response.body).not_to include("Promo ajena")

    get edit_admin_novedad_path(ajena)
    expect(response).to have_http_status(:not_found)
  end
end
