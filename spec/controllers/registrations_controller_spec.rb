require "rails_helper"

RSpec.describe "Registrations", type: :request do
  it "new" do
    get new_registro_path
    expect(response).to have_http_status(:success)
  end

  it "crea el usuario, inicia sesión y asigna rol miembro" do
    expect {
      post registro_path, params: { user: {
        nombre: "Ana Prueba",
        email_address: "ana@example.com",
        password: "supersecreta1",
        password_confirmation: "supersecreta1"
      } }
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present

    user = User.find_by!(email_address: "ana@example.com")
    expect(user.rol).to eq("miembro")
    expect(user.fecha_ingreso).to eq(Date.current)
  end

  it "rol no es asignable por mass-assignment" do
    post registro_path, params: { user: {
      nombre: "Intruso",
      email_address: "intruso@example.com",
      password: "supersecreta1",
      password_confirmation: "supersecreta1",
      rol: "admin"
    } }

    expect(User.find_by!(email_address: "intruso@example.com").rol).to eq("miembro")
  end

  it "no crea el usuario con contraseñas distintas" do
    expect {
      post registro_path, params: { user: {
        nombre: "Ana",
        email_address: "ana2@example.com",
        password: "supersecreta1",
        password_confirmation: "otracosa"
      } }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
