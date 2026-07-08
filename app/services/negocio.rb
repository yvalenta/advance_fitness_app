# Parámetros del negocio (SDD §04): un único lugar para clonar la app a otro
# gimnasio. Lee config/negocio.yml y permite override por variable de entorno
# (útil en producción vía Kamal secrets). PORO sin acceso a base ni sesión.
module Negocio
  DATOS = Rails.application.config_for(:negocio).freeze

  def self.nombre = ENV["NEGOCIO_NOMBRE"].presence || DATOS[:nombre]
  def self.moneda = ENV["NEGOCIO_MONEDA"].presence || DATOS[:moneda]
  def self.precio_mensualidad = (ENV["PRECIO_MENSUALIDAD"].presence || DATOS[:precio_mensualidad]).to_i
  def self.precio_personalizado = (ENV["PRECIO_PERSONALIZADO"].presence || DATOS[:precio_personalizado]).to_i
  def self.duracion_dias = (ENV["MEMBRESIA_DURACION_DIAS"].presence || DATOS[:duracion_dias]).to_i
end
