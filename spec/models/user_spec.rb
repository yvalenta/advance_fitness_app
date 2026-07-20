require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    expect(user.email_address).to eq("downcased@example.com")
  end

  it "VIP siempre cuenta como premium, sin importar la suscripción (Fase 12.2)" do
    expect(users(:one).premium?).to be_falsey
    users(:one).update!(vip: true)
    expect(users(:one).premium?).to be_truthy
  end
end
