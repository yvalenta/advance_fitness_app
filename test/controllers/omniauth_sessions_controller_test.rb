require "test_helper"

class OmniauthSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    Rails.application.env_config.delete("omniauth.auth")
  end

  test "creates a user and session for a new google account" do
    mock_google_auth email: "nuevo@example.com"

    assert_difference "User.count", 1 do
      get omniauth_callback_url(provider: "google_oauth2")
    end

    assert_redirected_to root_url
    assert cookies[:session_id].present?
    assert_equal "Usuario Google", User.find_by!(email_address: "nuevo@example.com").nombre
  end

  test "signs in an existing user without duplicating it" do
    user = users(:one)
    mock_google_auth email: user.email_address

    assert_no_difference "User.count" do
      get omniauth_callback_url(provider: "google_oauth2")
    end

    assert_redirected_to root_url
    assert_equal user, Session.order(:created_at).last.user
  end

  test "failure redirects to login with alert" do
    get auth_failure_url
    assert_redirected_to new_session_path
  end

  private
    def mock_google_auth(email:)
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "123456789",
        info: { email: email, name: "Usuario Google" }
      )
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    end
end
