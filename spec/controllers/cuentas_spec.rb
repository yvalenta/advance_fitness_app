require "rails_helper"

# Fase 17 (Nota 22): cambiar credenciales exige SIEMPRE probar la contraseña
# actual. El fixture global usa "password".
RSpec.describe "Cuentas", type: :request do
  let(:miembro) { users(:one) }

  it "requiere sesión" do
    patch cuenta_path, params: { user: { email_address: "x@x.com" } }
    expect(response).to redirect_to(new_session_path)
  end

  it "cambia la contraseña probando la actual y cierra las otras sesiones" do
    otra_sesion = miembro.sessions.create!
    sign_in_as miembro

    patch cuenta_path, params: { user: {
      password_challenge: "password",
      password: "nueva-clave-123", password_confirmation: "nueva-clave-123"
    } }

    expect(response).to redirect_to(edit_perfil_path)
    expect(miembro.reload.authenticate("nueva-clave-123")).to be_truthy
    expect(Session.exists?(otra_sesion.id)).to be(false)   # las demás, fuera
    expect(miembro.sessions.count).to eq(1)                # la actual sigue viva
  end

  it "con el challenge equivocado no cambia NADA" do
    sign_in_as miembro

    patch cuenta_path, params: { user: {
      password_challenge: "incorrecta",
      password: "nueva-clave-123", password_confirmation: "nueva-clave-123"
    } }

    expect(miembro.reload.authenticate("password")).to be_truthy
    expect(flash[:alert]).to be_present
  end

  it "omitir el challenge en el request tampoco lo salta" do
    sign_in_as miembro

    patch cuenta_path, params: { user: { email_address: "colado@evil.com" } }

    expect(miembro.reload.email_address).not_to eq("colado@evil.com")
    expect(flash[:alert]).to be_present
  end

  it "cambia el correo con el challenge correcto" do
    sign_in_as miembro

    patch cuenta_path, params: { user: {
      email_address: "nuevo@advancefitness.local", password_challenge: "password"
    } }

    expect(miembro.reload.email_address).to eq("nuevo@advancefitness.local")
  end

  it "un correo ya registrado en el tenant se rechaza" do
    sign_in_as miembro

    patch cuenta_path, params: { user: {
      email_address: users(:two).email_address, password_challenge: "password"
    } }

    expect(miembro.reload.email_address).not_to eq(users(:two).email_address)
    expect(flash[:alert]).to match(/registrado/i)
  end
end
