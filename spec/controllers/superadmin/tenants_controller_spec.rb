require "rails_helper"

RSpec.describe "Superadmin::Tenants", type: :request do
  let(:superadmin) do
    User.create!(email_address: "sa@x.com", password: "clave1234", rol: "superadmin", nombre: "SA")
  end

  before { host! "comercial.example.com" }

  it "el admin de un tenant no puede acceder" do
    host! "advance-fitness.example.com"
    sign_in_as users(:admin)
    get superadmin_tenants_path
    expect(response).to redirect_to(root_path)
  end

  it "el superadmin lista tenants" do
    sign_in_as superadmin
    get superadmin_tenants_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Advance Fitness")
  end

  it "crea un tenant nuevo y su admin inicial" do
    sign_in_as superadmin

    expect {
      post superadmin_tenants_path, params: {
        tenant: { nombre: "Vital", slug: "vital", tipo_entidad: "gimnasio",
                  email_contacto: "vital@x.com", activo: "1",
                  admin_nombre: "Dueño Vital", admin_email: "duenio@vital.com",
                  features_habilitadas: { membresias: "1" } }
      }
    }.to change(Tenant, :count).by(1).and change(User, :count).by(1)

    tenant = Tenant.find_by!(slug: "vital")
    admin = User.find_by!(email_address: "duenio@vital.com")
    expect(admin.tenant).to eq(tenant)
    expect(admin.admin?).to be true
    expect(response).to redirect_to(superadmin_tenant_path(tenant))
  end

  it "membresias_habilitadas se apaga si no vino la clave (checkbox sin marcar)" do
    sign_in_as superadmin
    post superadmin_tenants_path, params: {
      tenant: { nombre: "Coach X", slug: "coach-x", tipo_entidad: "entrenador",
                email_contacto: "coach@x.com", activo: "1" }
    }
    expect(Tenant.find_by!(slug: "coach-x").membresias_habilitadas?).to be false
  end
end
