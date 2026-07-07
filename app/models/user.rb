class User < ApplicationRecord
  ROLES = %w[miembro entrenador admin].freeze
  SOMATOTIPOS = %w[ectomorfo mesomorfo endomorfo].freeze

  # Factores de actividad para el TDEE (SDD §07: 1.2–1.9). La columna es
  # decimal(2,1), por eso los factores clásicos van redondeados a 1 decimal.
  NIVELES_ACTIVIDAD = {
    1.2 => "Sedentario (poco o nada de ejercicio)",
    1.4 => "Ligero (1–3 días por semana)",
    1.6 => "Moderado (3–5 días por semana)",
    1.8 => "Intenso (6–7 días por semana)",
    1.9 => "Atleta (dos sesiones diarias)"
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :membresia, dependent: :destroy
  has_many :accesos, dependent: :destroy
  has_many :objetivos_nutricionales, dependent: :destroy
  has_many :registros_calorias, dependent: :destroy
  has_many :suscripciones, dependent: :destroy
  has_many :planes_personalizados, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # En la zona horaria de la app (el default CURRENT_DATE de Postgres es UTC
  # y entre 19:00 y 24:00 hora Colombia daría el día siguiente)
  before_validation(on: :create) { self.fecha_ingreso ||= Date.current }

  validates :rol, inclusion: { in: ROLES }
  validates :sexo, inclusion: { in: %w[M F] }, allow_nil: true
  validates :somatotipo, inclusion: { in: SOMATOTIPOS }, allow_nil: true
  validates :talla_cm, numericality: { greater_than: 0 }, allow_nil: true
  validates :nivel_actividad, numericality: { in: 1.2..1.9 }, allow_nil: true

  def staff? = rol.in?(%w[entrenador admin])
  def admin? = rol == "admin"
  def entrenador? = rol == "entrenador"

  def objetivo_activo = objetivos_nutricionales.find_by(activo: true)

  def suscripcion_activa = suscripciones.activas.includes(:plan).first

  # Premium = suscripción activa al plan personalizado (validado en DB, SDD §08)
  def premium?
    suscripcion_activa&.plan&.personalizado? || false
  end

  def plan_aprobado = planes_personalizados.aprobados.order(created_at: :desc).first

  # La edad se deriva de la fecha de nacimiento, nunca se guarda (SDD §07)
  def edad
    return unless fecha_nacimiento

    hoy = Date.current
    hoy.year - fecha_nacimiento.year - (fecha_nacimiento.change(year: hoy.year) > hoy ? 1 : 0)
  end

  # Datos mínimos para calcular TDEE (Mifflin-St Jeor + factor de actividad)
  def perfil_nutricional_completo?
    fecha_nacimiento.present? && sexo.present? && talla_cm.present? && nivel_actividad.present?
  end

  # Login con Google: encuentra o crea el usuario por email verificado.
  # Los usuarios creados vía OAuth reciben un password aleatorio (pueden
  # fijar el suyo luego con el flujo de reset).
  def self.from_omniauth(auth)
    find_or_create_by!(email_address: auth.info.email) do |user|
      user.nombre = auth.info.name.to_s
      user.password = SecureRandom.base58(32)
    end
  end
end
