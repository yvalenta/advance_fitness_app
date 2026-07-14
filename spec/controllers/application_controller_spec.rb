require "rails_helper"

# El pooler de Supabase (modo sesión) tiene un límite duro de 15 conexiones
# para todo el proyecto; sin este rescate global, quedarse sin conexión
# disponible era un 500 genérico en cualquier acción (julio 2026).
RSpec.describe "Rescate global de errores de conexión", type: :request do
  it "convierte un fallo de conexión a la base en un aviso reintentable, no un 500" do
    sign_in_as users(:one)
    allow(User).to receive(:find).and_raise(PG::ConnectionBad, "max clients reached")

    get admin_user_path(users(:one))

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("muy ocupado")
  end
end
