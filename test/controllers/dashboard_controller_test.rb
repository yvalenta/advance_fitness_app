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
  end
end
