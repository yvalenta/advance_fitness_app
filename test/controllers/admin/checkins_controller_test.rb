require "test_helper"

class Admin::CheckinsControllerTest < ActionDispatch::IntegrationTest
  test "un miembro no accede al panel de check-in" do
    sign_in_as users(:one)
    get admin_checkins_path
    assert_redirected_to root_path
  end

  test "staff registra el check-in de una membresía activa" do
    sign_in_as users(:entrenador)

    assert_difference "Acceso.count", 1 do
      post admin_checkins_path, params: { user_id: users(:one).id }
    end
    assert_redirected_to admin_checkins_path
    assert_equal "checkin", Acceso.recientes.first.tipo
  end

  test "membresía vencida no registra acceso y pide renovación" do
    sign_in_as users(:admin)

    assert_no_difference "Acceso.count" do
      post admin_checkins_path, params: { user_id: users(:two).id }
    end
    assert_match(/renovación/, flash[:alert])
  end

  test "miembro sin membresía no registra acceso" do
    sign_in_as users(:admin)

    assert_no_difference "Acceso.count" do
      post admin_checkins_path, params: { user_id: users(:entrenador).id }
    end
    assert_match(/no tiene membresía/, flash[:alert])
  end
end
