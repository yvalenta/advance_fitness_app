require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @miembro = users(:one)
    @otro = users(:two)
    @admin = users(:admin)
    @entrenador = users(:entrenador)
  end

  test "un miembro ve y edita su propio perfil" do
    assert UserPolicy.new(@miembro, @miembro).show?
    assert UserPolicy.new(@miembro, @miembro).update?
  end

  test "un miembro no ve ni edita a otro" do
    assert_not UserPolicy.new(@miembro, @otro).show?
    assert_not UserPolicy.new(@miembro, @otro).update?
  end

  test "staff ve a todos pero solo admin edita" do
    assert UserPolicy.new(@entrenador, @otro).show?
    assert_not UserPolicy.new(@entrenador, @otro).update?

    assert UserPolicy.new(@admin, @otro).show?
    assert UserPolicy.new(@admin, @otro).update?
  end

  test "nadie elimina usuarios" do
    assert_not UserPolicy.new(@admin, @otro).destroy?
  end

  test "el scope de un miembro solo lo incluye a él" do
    assert_equal [ @miembro ], UserPolicy::Scope.new(@miembro, User).resolve.to_a
    assert_equal User.count, UserPolicy::Scope.new(@admin, User).resolve.count
  end
end
