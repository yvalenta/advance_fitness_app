require "rails_helper"

# El pooler de Supabase (modo sesión) tiene un límite duro de 15 conexiones
# para todo el proyecto; sin este rescate global, quedarse sin conexión
# disponible era un 500 genérico en cualquier acción (julio 2026).
RSpec.describe "Rescate global de errores de conexión", type: :request do
  it "convierte un fallo de conexión a la base en un aviso reintentable, sin redirect" do
    sign_in_as users(:one)
    allow(User).to receive(:find).and_raise(PG::ConnectionBad, "max clients reached")

    get admin_user_path(users(:one))

    # Sin redirect: un redirect lo sigue el navegador solo y, si la página de
    # destino también toca la base mientras sigue saturada, produce un loop
    # infinito autoinfligido (bug real de producción, julio 2026).
    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("muy ocupado")
  end

  it "responde sin cuerpo HTML en peticiones turbo_stream" do
    sign_in_as users(:one)
    allow(User).to receive(:find).and_raise(PG::ConnectionBad, "max clients reached")

    get admin_user_path(users(:one)), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to be_empty
  end
end
