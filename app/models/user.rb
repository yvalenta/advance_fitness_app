class User < ApplicationRecord
  # miembro/entrenador/admin viven dentro de un tenant; superadmin y
  # comercializador operan en el portal comercial global (SDD §16.6).
  ROLES = %w[miembro entrenador admin superadmin comercializador].freeze
  ROLES_GLOBALES = %w[superadmin comercializador].freeze
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
  belongs_to :tenant, optional: true
  has_many :sessions, dependent: :destroy
  has_one :membresia, dependent: :destroy
  has_many :accesos, dependent: :destroy
  has_many :objetivos_nutricionales, dependent: :destroy
  has_many :registros_calorias, dependent: :destroy
  has_many :suscripciones, dependent: :destroy
  has_many :planes_personalizados, dependent: :destroy
  has_many :mediciones, dependent: :destroy
  has_many :registros_entrenamiento, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # En la zona horaria de la app (el default CURRENT_DATE de Postgres es UTC
  # y entre 19:00 y 24:00 hora Colombia daría el día siguiente)
  before_validation(on: :create) { self.fecha_ingreso ||= Date.current }

  validates :email_address, presence: true, uniqueness: true
  validates :rol, inclusion: { in: ROLES }
  # superadmin/comercializador no pertenecen a ningún tenant; los demás sí.
  validates :tenant, presence: true, unless: -> { rol.in?(ROLES_GLOBALES) }
  validates :sexo, inclusion: { in: %w[M F] }, allow_nil: true
  validates :somatotipo, inclusion: { in: SOMATOTIPOS }, allow_nil: true
  validates :talla_cm, numericality: { greater_than: 0 }, allow_nil: true
  validates :nivel_actividad, numericality: { in: 1.2..1.9 }, allow_nil: true

  def staff? = rol.in?(%w[entrenador admin])
  def admin? = rol == "admin"
  def entrenador? = rol == "entrenador"
  def superadmin? = rol == "superadmin"
  def comercializador? = rol == "comercializador"
  def global? = rol.in?(ROLES_GLOBALES)

  def objetivo_activo = objetivos_nutricionales.find_by(activo: true)

  def ultima_medicion = mediciones.recientes.first

  # Peso vigente: última medición, o el snapshot del objetivo activo (Fase 5.9)
  def peso_actual = ultima_medicion&.peso_kg || objetivo_activo&.peso_kg

  def suscripcion_activa = suscripciones.activas.includes(:plan).first

  # Premium = suscripción activa al plan personalizado (validado en DB, SDD §08).
  # VIP (Fase 12.2, marcado a mano por staff) siempre cuenta como premium.
  def premium?
    vip? || suscripcion_activa&.plan&.personalizado? || false
  end

  # Mínimo de datos para desbloquear el Analista de Performance (Fase 12):
  # al menos 3 semanas distintas con series registradas en las últimas 3
  # semanas — evita un análisis con una sola sesión sin tendencia real.
  MINIMO_SEMANAS_PARA_ANALISIS = 3

  def datos_suficientes_para_analisis?
    desde = Date.current.beginning_of_week - (MINIMO_SEMANAS_PARA_ANALISIS - 1).weeks
    fechas = DetalleEntrenamiento.joins(:registro_entrenamiento)
                                 .where(registro_entrenamiento: { user_id: id, fecha: desde..Date.current })
                                 .distinct.pluck(:fecha)
    fechas.map(&:beginning_of_week).uniq.size >= MINIMO_SEMANAS_PARA_ANALISIS
  end

  # Ventana de frecuencia del tier de análisis asignado por staff (Fase 12).
  def puede_analizar?
    return false unless premium?
    tier = suscripcion_activa.analisis_tier
    ultimo = FeedbackIa.joins(:registro_entrenamiento)
                       .where(registro_entrenamiento: { user_id: id }, estado: "listo")
                       .maximum(:created_at)
    return true if ultimo.nil?

    ultimo < Suscripcion::ANALISIS_VENTANA_DIAS.fetch(tier).days.ago
  end

  def plan_aprobado = planes_personalizados.aprobados.order(created_at: :desc).first

  # El plan más reciente del miembro (borrador o publicado) — el que edita el staff
  def plan_actual = planes_personalizados.order(created_at: :desc).first

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
  # fijar el suyo luego con el flujo de reset). En multi-tenant (SDD §16.6)
  # el nuevo user hereda el tenant del request (nil = portal comercial).
  def self.from_omniauth(auth, tenant: Current.tenant)
    find_or_create_by!(email_address: auth.info.email) do |user|
      user.nombre = auth.info.name.to_s
      user.password = SecureRandom.base58(32)
      user.tenant = tenant
    end
  end
end
