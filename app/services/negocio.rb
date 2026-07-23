# Parámetros del negocio (SDD §04): un único lugar para clonar la app a otro
# gimnasio. Lee config/negocio.yml y permite override por variable de entorno
# (útil en producción vía Kamal secrets). PORO sin acceso a base ni sesión.
module Negocio
  DATOS = Rails.application.config_for(:negocio).freeze

  # Multi-tenant (SDD §16.6): si el request tiene `Current.tenant` (resuelto
  # por subdominio), los valores por-tenant tienen prioridad sobre el ENV/YAML
  # global. Fuera de un request web (jobs/mailers) `Current.tenant` es nil y
  # se cae al ENV/YAML — mismo comportamiento single-tenant original.
  def self.nombre = Current.tenant&.nombre.presence || ENV["NEGOCIO_NOMBRE"].presence || DATOS[:nombre]
  def self.ciudad = ENV["NEGOCIO_CIUDAD"].presence || DATOS[:ciudad]
  def self.moneda = ENV["NEGOCIO_MONEDA"].presence || DATOS[:moneda]
  # Si se define, el logo se renderiza como imagen (white-label); si no, se usa
  # el fisicoculturista vectorial de marca (shared/_logo).
  def self.logo_url = ENV["NEGOCIO_LOGO_URL"].presence || DATOS[:logo_url].presence
  def self.precio_mensualidad = Current.tenant&.precio_mensualidad || (ENV["PRECIO_MENSUALIDAD"].presence || DATOS[:precio_mensualidad]).to_i
  def self.precio_personalizado = Current.tenant&.precio_personalizado || (ENV["PRECIO_PERSONALIZADO"].presence || DATOS[:precio_personalizado]).to_i
  def self.duracion_dias = Current.tenant&.duracion_dias || (ENV["MEMBRESIA_DURACION_DIAS"].presence || DATOS[:duracion_dias]).to_i

  # Color de instalación PWA + <meta theme-color>. Usa el `primary` de la paleta
  # del tenant si es hex válido (SDD §16.6: solo se aceptan hex para evitar CSS
  # injection); si no, el midnight de marca. El icono del manifest sigue global
  # — un `variant` para cuadrar el logo del tenant a 512×512 requiere ruby-vips
  # (no disponible en producción, ver commit 75628c9).
  DEFAULT_THEME_COLOR = "#0b1220".freeze
  def self.theme_color
    paleta = Current.tenant&.paleta_colores
    valor = paleta.is_a?(Hash) ? paleta["primary"].to_s : ""
    valor.match?(/\A#[0-9a-fA-F]{3,8}\z/) ? valor : DEFAULT_THEME_COLOR
  end
end
