require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registro_path
    assert_response :success
  end

  test "crea el usuario, inicia sesión y asigna rol miembro" do
    assert_difference "User.count", 1 do
      post registro_path, params: { user: {
        nombre: "Ana Prueba",
        email_address: "ana@example.com",
        password: "supersecreta1",
        password_confirmation: "supersecreta1"
      } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?

    user = User.find_by!(email_address: "ana@example.com")
    assert_equal "miembro", user.rol
    assert_equal Date.current, user.fecha_ingreso
  end

  test "rol no es asignable por mass-assignment" do
    post registro_path, params: { user: {
      nombre: "Intruso",
      email_address: "intruso@example.com",
      password: "supersecreta1",
      password_confirmation: "supersecreta1",
      rol: "admin"
    } }

    assert_equal "miembro", User.find_by!(email_address: "intruso@example.com").rol
  end

  test "no crea el usuario con contraseñas distintas" do
    assert_no_difference "User.count" do
      post registro_path, params: { user: {
        nombre: "Ana",
        email_address: "ana2@example.com",
        password: "supersecreta1",
        password_confirmation: "otracosa"
      } }
    end

    assert_response :unprocessable_entity
  end
end
