require "rails_helper"

# Panel Admin → Funcionalidades (Fase 18d): el admin del tenant enciende y
# apaga módulos; apagar esconde links Y cierra rutas, sin borrar datos.
RSpec.describe "Admin::Funcionalidades", type: :request do
  it "un miembro no accede" do
    sign_in_as users(:one)
    get admin_funcionalidades_path
    expect(response).to redirect_to(root_path)
  end

  it "el entrenador tampoco: es decisión del admin" do
    sign_in_as users(:entrenador)
    get admin_funcionalidades_path
    expect(response).to redirect_to(root_path)
  end

  it "el admin apaga el blog: persiste, el navbar lo esconde y la ruta se cierra" do
    sign_in_as users(:admin)

    get admin_funcionalidades_path
    expect(response).to have_http_status(:success)

    patch admin_funcionalidades_path, params: { funcionalidades: {
      membresias: "1", nutricion: "1", gamificacion: "1", ciclo: "1", blog: "0", novedades: "1"
    } }
    expect(response).to redirect_to(admin_funcionalidades_path)

    tenant = tenants(:advance_fitness).reload
    expect(tenant.feature?("blog")).to be false
    expect(tenant.feature?("nutricion")).to be true

    get blog_path
    expect(response).to redirect_to(root_path)

    get root_path
    expect(response.body).not_to include("Blog")
  end

  it "una feature apagada cierra la ruta también para el miembro" do
    tenants(:advance_fitness).update!(features_habilitadas: { "membresias" => true, "nutricion" => false })
    sign_in_as users(:one)

    get objetivo_path
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to include("no está habilitada")
  end

  it "gamificación apagada esconde la racha del dashboard y cierra el ranking" do
    tenants(:advance_fitness).update!(features_habilitadas: { "membresias" => true, "gamificacion" => false })
    sign_in_as users(:one)

    get root_path
    expect(response.body).not_to include("Racha")

    get ranking_path
    expect(response).to redirect_to(root_path)
  end
end
