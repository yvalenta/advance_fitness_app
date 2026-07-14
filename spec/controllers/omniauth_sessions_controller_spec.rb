require "rails_helper"

RSpec.describe "OmniauthSessions", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    Rails.application.env_config.delete("omniauth.auth")
  end

  it "creates a user and session for a new google account" do
    mock_google_auth email: "nuevo@example.com"

    expect {
      get omniauth_callback_url(provider: "google_oauth2")
    }.to change(User, :count).by(1)

    expect(response).to redirect_to(root_url)
    expect(cookies[:session_id]).to be_present
    expect(User.find_by!(email_address: "nuevo@example.com").nombre).to eq("Usuario Google")
  end

  it "signs in an existing user without duplicating it" do
    user = users(:one)
    mock_google_auth email: user.email_address

    expect {
      get omniauth_callback_url(provider: "google_oauth2")
    }.not_to change(User, :count)

    expect(response).to redirect_to(root_url)
    expect(Session.order(:created_at).last.user).to eq(user)
  end

  it "failure redirects to login with alert" do
    get auth_failure_url
    expect(response).to redirect_to(new_session_path)
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
