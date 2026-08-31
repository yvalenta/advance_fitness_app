class User < ApplicationRecord
  # miembro/entrenador/recepcion/admin viven dentro de un tenant; superadmin y
  # comercializador operan en el portal comercial global (SDD §16.6).
  ROLES = %w[miembro entrenador admin superadmin comercializador recepcion].freeze
  ROLES_GLOBALES = %w[superadmin comercializador].freeze
  SOMATOTIPOS = %w[ectomorfo mesomorfo endomorfo].freeze
  # Preferencia de apariencia (Fase 16, Nota 21): "sistema" sigue al SO.
  TEMAS = %w[oscuro claro sistema].freeze
  # Acento personal (Fase 17, Nota 22f): "volt" = el de la marca/tenant.
  ACENTOS = %w[volt ambar azul].freeze

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
  # CONTRATO redefinido (tarea 2026-08-31, puestos): `tenant_id` y `rol`
  # dejan de ser la verdad de pertenencia y pasan a ser LA CACHE de "dónde
  # está parada la cuenta ahora y con qué rol AHÍ". La verdad es `puestos`
  # (un rol por gimnasio); la cache se mantiene coherente porque SOLO el
  # embudo del cambio de organización la reescribe, copiando del puesto
  # destino. Todo lo que ya filtra por users.tenant_id/rol sigue siendo
  # correcto — lee la posición vigente, no la lista de pertenencias.
  belongs_to :tenant, optional: true
  # La verdad de pertenencia N:M. `destroy` (no delete_all como los
  # append-only): son filas vivas sin patrón readonly — al borrar la cuenta
  # se van sus puestos.
  has_many :puestos, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_one :membresia, dependent: :destroy
  has_many :accesos, dependent: :destroy
  has_many :objetivos_nutricionales, dependent: :destroy
  has_many :registros_calorias, dependent: :destroy
  has_many :suscripciones, dependent: :destroy
  has_many :planes_personalizados, dependent: :destroy
  has_many :mediciones, dependent: :destroy
  has_many :registros_entrenamiento, dependent: :destroy
  # Filas append-only (readonly tras persistir): `destroy` levantaría
  # ReadOnlyRecord, por eso `delete_all` — al borrar el user, el rastro
  # de sus consentimientos se va con él (dato personal, RGPD-friendly).
  has_many :consentimientos, dependent: :delete_all
  # Log del cambio de organización: append-only como consentimientos →
  # delete_all; su IP y user-agent son dato personal y se van con la cuenta.
  has_many :cambios_organizacion, dependent: :delete_all
  # Motor de juego (Fase 14.12): el ledger también es append-only → delete_all.
  has_many :registros_puntos, dependent: :delete_all
  has_one :perfil_juego, dependent: :destroy
  has_many :logros_obtenidos, dependent: :destroy
  # Récords personales (Fase 14.13): histórico que solo escribe el detector.
  has_many :records_personales, dependent: :delete_all
  # Dato de salud sensible (Fase 14.15): se va con la cuenta. `delete_all`
  # también libera la FK de creado_por (siempre es la propia usuaria).
  has_many :ciclos_menstruales, dependent: :delete_all
  has_many :suscripciones_push, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # En la zona horaria de la app (el default CURRENT_DATE de Postgres es UTC
  # y entre 19:00 y 24:00 hora Colombia daría el día siguiente)
  before_validation(on: :create) { self.fecha_ingreso ||= Date.current }

  # INVARIANTE del contrato cache/verdad (tarea 2026-08-31): toda cuenta con
  # `tenant_id` presente y rol de tenant tiene un puesto en ese par con el
  # MISMO rol. En el mismo espíritu que TenantDesnormalizado ("que no se
  # pueda persistir una fila incoherente aunque el controller se olvide"),
  # el espejo vive en el modelo y no en cada call-site: registro público,
  # alta en el mostrador, alta del admin inicial de un tenant nuevo, OAuth y
  # seeds crean o mueven la cache y este callback materializa/sincroniza el
  # puesto del par. Sin él, un user nuevo no pasaría jamás
  # `verificar_pertenencia_al_tenant` (que exige puesto). Las fixtures no
  # corren callbacks: puestos.yml las cubre.
  #
  # La dirección inversa (puesto → cache) es SOLO del embudo: `estacionar_en!`.
  after_save :sincronizar_puesto_con_la_cache,
             if: -> { saved_change_to_tenant_id? || saved_change_to_rol? }

  validates :email_address, presence: true, uniqueness: { scope: :tenant_id, message: "ya está registrado en este gimnasio" }
  validates :rol, inclusion: { in: ROLES }
  # superadmin/comercializador no pertenecen a ningún tenant; los demás sí.
  validates :tenant, presence: true, unless: -> { rol.in?(ROLES_GLOBALES) }
  validates :sexo, inclusion: { in: %w[M F] }, allow_nil: true
  validates :somatotipo, inclusion: { in: SOMATOTIPOS }, allow_nil: true
  validates :talla_cm, numericality: { greater_than: 0 }, allow_nil: true
  validates :nivel_actividad, numericality: { in: 1.2..1.9 }, allow_nil: true
  validates :tema, inclusion: { in: TEMAS }
  validates :acento, inclusion: { in: ACENTOS }

  # DOS permisos distintos, a propósito:
  #
  # `staff?` es el permiso de ENTRENAMIENTO — rutinas, planes personalizados,
  # mediciones/antropometría, plantillas, series y el Analista. Lo usan ~20
  # policies.
  # `mostrador?` es el permiso de RECEPCIÓN — cobros, check-ins, membresías y
  # alta de miembros.
  #
  # `recepcion` entra SOLO en el segundo. Meterlo dentro de `staff?` habría
  # sido una línea, y habría abierto de un golpe MedicionPolicy,
  # PlanPersonalizadoPolicy, DetalleEntrenamientoPolicy, las plantillas, Post
  # y Novedad: quien atiende el mostrador cobra y da acceso, pero no lee el
  # plan de entrenamiento ni las medidas del cuerpo de nadie. `admin` sí está
  # en los dos porque el admin del gimnasio hace ambos oficios.
  def staff? = rol.in?(%w[entrenador admin])
  def mostrador? = rol.in?(%w[recepcion admin])
  def recepcion? = rol == "recepcion"
  def admin? = rol == "admin"
  def entrenador? = rol == "entrenador"
  def superadmin? = rol == "superadmin"
  def comercializador? = rol == "comercializador"
  def global? = rol.in?(ROLES_GLOBALES)

  # El embudo del cambio de organización (selector + pase firmado) para la
  # cuenta EN un tenant: valida que el puesto del par exista (levanta
  # ActiveRecord::RecordNotFound si no — jamás se estaciona sin pertenencia)
  # y sincroniza la cache `tenant_id`+`rol` en una transacción, copiando el
  # rol DEL PUESTO destino. Es la ÚNICA dirección puesto → cache; nadie más
  # debe reescribir la cache para "cambiar de gimnasio".
  #
  # Divergencia conocida que este método NO resuelve (documentada a
  # propósito): el email es único por (email_address, tenant_id) — si en el
  # tenant destino ya existe OTRA cuenta con el mismo correo (el viejo
  # workaround de "dos cuentas para dos gimnasios"), el update! levanta
  # RecordInvalid y el salto no ocurre. Esas cuentas duplicadas se fusionan a
  # mano antes de darles un segundo puesto.
  def estacionar_en!(tenant)
    puesto = puestos.find_by!(tenant_id: tenant.id)
    transaction do
      update!(tenant_id: tenant.id, rol: puesto.rol)
    end
    puesto
  end

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

  private
    # Ver el comentario del after_save arriba. `find_or_initialize_by` +
    # update! y no upsert: pasa por las validaciones de Puesto (roles
    # globales jamás — el guard de abajo lo corta antes) y el único de la
    # base respalda ante una carrera. Cuando `estacionar_en!` copia el rol
    # del puesto a la cache, este callback re-encuentra el mismo puesto con
    # el mismo rol y no toca nada.
    def sincronizar_puesto_con_la_cache
      return if tenant_id.blank? || rol.in?(ROLES_GLOBALES)

      puesto = puestos.find_or_initialize_by(tenant_id: tenant_id)
      puesto.update!(rol: rol) if puesto.new_record? || puesto.rol != rol
    end
end
