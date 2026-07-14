require "rails_helper"

RSpec.describe "Passwords", type: :request do
  before { @user = User.take }

  it "new" do
    get new_password_path
    expect(response).to have_http_status(:success)
  end

  it "create" do
    expect {
      post passwords_path, params: { email_address: @user.email_address }
    }.to have_enqueued_mail(PasswordsMailer, :reset).with(@user)
    expect(response).to redirect_to(new_session_path)

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  it "create for an unknown user redirects but sends no mail" do
    expect {
      post passwords_path, params: { email_address: "missing-user@example.com" }
    }.not_to have_enqueued_mail
    expect(response).to redirect_to(new_session_path)

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  it "edit" do
    get edit_password_path(@user.password_reset_token)
    expect(response).to have_http_status(:success)
  end

  it "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    expect(response).to redirect_to(new_password_path)

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  it "update" do
    expect {
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      expect(response).to redirect_to(new_session_path)
    }.to change { @user.reload.password_digest }

    follow_redirect!
    assert_notice "Password has been reset"
  end

  it "update with non matching passwords" do
    token = @user.password_reset_token
    expect {
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      expect(response).to redirect_to(edit_password_path(token))
    }.not_to change { @user.reload.password_digest }

    follow_redirect!
    assert_notice "Passwords did not match"
  end

  private

  def assert_notice(text)
    assert_select "div", /#{text}/
  end
end
