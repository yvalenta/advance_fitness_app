require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # Fase 5.14: evita repetir el valor crudo de generado_por (y la palabra "IA")
  # en las vistas de staff.
  test "origen_plan traduce los tres generadores conocidos" do
    assert_equal "análisis automático", origen_plan(PlanPersonalizado.new(generado_por: "ia"))
    assert_equal "plan de membresía", origen_plan(PlanPersonalizado.new(generado_por: "reglas"))
    assert_equal "entrenador", origen_plan(PlanPersonalizado.new(generado_por: "entrenador"))
  end
end
