require "test_helper"

class MembresiaPolicyTest < ActiveSupport::TestCase
  setup do
    @membresia = membresias(:activa_one)
    @dueno = users(:one)
    @otro = users(:two)
    @entrenador = users(:entrenador)
    @admin = users(:admin)
  end

  test "el miembro ve su membresía pero no la de otro" do
    assert MembresiaPolicy.new(@dueno, @membresia).show?
    assert_not MembresiaPolicy.new(@otro, @membresia).show?
  end

  test "solo staff crea y edita" do
    assert_not MembresiaPolicy.new(@dueno, @membresia).create?
    assert MembresiaPolicy.new(@entrenador, @membresia).create?
    assert MembresiaPolicy.new(@admin, @membresia).update?
  end

  test "solo admin renueva (registra pagos)" do
    assert_not MembresiaPolicy.new(@entrenador, @membresia).renovar?
    assert MembresiaPolicy.new(@admin, @membresia).renovar?
  end

  test "nadie elimina membresías" do
    assert_not MembresiaPolicy.new(@admin, @membresia).destroy?
  end

  test "scope: miembro solo la propia, staff todas" do
    assert_equal [ @membresia ], MembresiaPolicy::Scope.new(@dueno, Membresia).resolve.to_a
    assert_equal Membresia.count, MembresiaPolicy::Scope.new(@admin, Membresia).resolve.count
  end
end
