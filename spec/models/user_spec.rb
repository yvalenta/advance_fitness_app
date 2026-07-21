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

  it "requiere tenant para miembro/entrenador/admin (SDD §16.6)" do
    user = User.new(email_address: "sin@tenant.com", password: "clave1234", rol: "miembro")
    expect(user.valid?).to be_falsey
    expect(user.errors[:tenant]).to be_present
  end

  it "no requiere tenant para superadmin ni comercializador" do
    %w[superadmin comercializador].each do |rol|
      user = User.new(email_address: "#{rol}@x.com", password: "clave1234", rol: rol)
      expect(user.valid?).to be_truthy, "#{rol} debería ser válido sin tenant: #{user.errors.full_messages}"
    end
  end

  it "helpers de rol global" do
    expect(User.new(rol: "superadmin").superadmin?).to be true
    expect(User.new(rol: "comercializador").comercializador?).to be true
    expect(User.new(rol: "superadmin").global?).to be true
    expect(User.new(rol: "miembro").global?).to be false
  end
end
