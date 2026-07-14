require "rails_helper"

RSpec.describe "Sessions", type: :request do
  before { @user = User.take }

  it "new" do
    get new_session_path
    expect(response).to have_http_status(:success)
  end

  it "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_truthy
  end

  it "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_nil
  end

  it "destroy" do
    sign_in_as(User.take)

    delete session_path

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_empty
  end
end
