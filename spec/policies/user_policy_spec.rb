require "rails_helper"

RSpec.describe UserPolicy, type: :model do
  before do
    @miembro = users(:one)
    @otro = users(:two)
    @admin = users(:admin)
    @entrenador = users(:entrenador)
    @recepcion = users(:recepcion)
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

  # Dar de alta al miembro en el mostrador (Flujo A del SDD). El rol NO se
  # asigna acá: eso vive en Admin::UsersController y sigue siendo solo del
  # admin, así que recepción no puede ascender a nadie ni ascenderse a sí
  # misma aunque cree y edite usuarios.
  it "recepción lista, ve, crea y edita miembros" do
    expect(UserPolicy.new(@recepcion, User).index?).to be_truthy
    expect(UserPolicy.new(@recepcion, @otro).show?).to be_truthy
    expect(UserPolicy.new(@recepcion, @otro).create?).to be_truthy
    expect(UserPolicy.new(@recepcion, @otro).update?).to be_truthy
  end

  it "el entrenador NO da de alta miembros (el alta es del mostrador)" do
    expect(UserPolicy.new(@entrenador, @otro).create?).to be_falsey
  end

  it "nadie elimina usuarios, tampoco recepción" do
    expect(UserPolicy.new(@admin, @otro).destroy?).to be_falsey
    expect(UserPolicy.new(@recepcion, @otro).destroy?).to be_falsey
  end

  it "el scope de un miembro solo lo incluye a él" do
    expect(UserPolicy::Scope.new(@miembro, User).resolve.to_a).to eq([ @miembro ])
    expect(UserPolicy::Scope.new(@admin, User).resolve.count).to eq(User.count)
    expect(UserPolicy::Scope.new(@recepcion, User).resolve.count).to eq(User.count)
  end
end
