require "test_helper"

class PerfilesControllerTest < ActionDispatch::IntegrationTest
  test "completa el perfil y redirige al objetivo" do
    sign_in_as users(:two)

    patch perfil_path, params: { user: {
      nombre: "Usuario Dos",
      fecha_nacimiento: "1998-05-10",
      sexo: "F",
      talla_cm: 162,
      nivel_actividad: 1.4
    } }

    assert_redirected_to objetivo_path
    assert users(:two).reload.perfil_nutricional_completo?
  end

  test "el rol no es asignable desde el perfil" do
    sign_in_as users(:one)

    patch perfil_path, params: { user: { nombre: "Uno Actualizado", rol: "admin" } }

    assert_equal "miembro", users(:one).reload.rol
    assert_equal "Uno Actualizado", users(:one).reload.nombre
  end
end
