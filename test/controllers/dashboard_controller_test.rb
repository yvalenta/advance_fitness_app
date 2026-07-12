require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "shows dashboard when authenticated" do
    user = users(:one)
    post session_url, params: { email_address: user.email_address, password: "password" }

    get root_url
    assert_response :success
    # El saludo usa solo el primer nombre del miembro
    assert_select "h1", text: /#{user.nombre.split.first}/
    # Fase 5.14: copy sin menciones a "IA" de cara al miembro
    assert_match "Planes personalizados", response.body
    assert_no_match(/\bIA\b/, response.body)
  end
end
