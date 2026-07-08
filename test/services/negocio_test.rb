require "test_helper"

class NegocioTest < ActiveSupport::TestCase
  test "lee los valores por defecto de config/negocio.yml" do
    assert_equal 80_000, Negocio.precio_mensualidad
    assert_equal 350_000, Negocio.precio_personalizado
    assert_equal 30, Negocio.duracion_dias
    assert Negocio.nombre.present?
  end

  test "una variable de entorno sobreescribe la config" do
    original = ENV["PRECIO_MENSUALIDAD"]
    ENV["PRECIO_MENSUALIDAD"] = "120000"
    assert_equal 120_000, Negocio.precio_mensualidad
  ensure
    original.nil? ? ENV.delete("PRECIO_MENSUALIDAD") : ENV["PRECIO_MENSUALIDAD"] = original
  end
end
