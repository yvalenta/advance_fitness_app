require "rails_helper"

RSpec.describe UserPolicy, type: :model do
  before do
    @miembro = users(:one)
    @otro = users(:two)
    @admin = users(:admin)
    @entrenador = users(:entrenador)
  end

  it "un miembro ve y edita su propio perfil" do
    expect(UserPolicy.new(@miembro, @miembro).show?).to be_truthy
    expect(UserPolicy.new(@miembro, @miembro).update?).to be_truthy
  end

  it "un miembro no ve ni edita a otro" do
    expect(UserPolicy.new(@miembro, @otro).show?).to be_falsey
    expect(UserPolicy.new(@miembro, @otro).update?).to be_falsey
  end

  it "staff ve y edita el perfil de cualquiera (el rol se restringe aparte, en el controller)" do
    expect(UserPolicy.new(@entrenador, @otro).show?).to be_truthy
    expect(UserPolicy.new(@entrenador, @otro).update?).to be_truthy

    expect(UserPolicy.new(@admin, @otro).show?).to be_truthy
    expect(UserPolicy.new(@admin, @otro).update?).to be_truthy
  end

  it "nadie elimina usuarios" do
    expect(UserPolicy.new(@admin, @otro).destroy?).to be_falsey
  end

  it "el scope de un miembro solo lo incluye a él" do
    expect(UserPolicy::Scope.new(@miembro, User).resolve.to_a).to eq([ @miembro ])
    expect(UserPolicy::Scope.new(@admin, User).resolve.count).to eq(User.count)
  end
end
