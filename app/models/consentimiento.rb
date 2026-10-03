# Registro append-only de consentimientos (Fase 14.11): cada otorgamiento o
# revocación es una FILA nueva con la versión del texto que el usuario aceptó,
# su IP y su user-agent — mismo espíritu auditable que `pagos`: se deja
# rastro, jamás se edita ni se borra físico. La vigencia no vive en una
# columna: es la última fila por (user, tipo).
class Consentimiento < ApplicationRecord
  # tabla_posiciones bloquea el ranking del motor de juego (Fase 14.12);
  # los de ciclo bloquean el futuro módulo de ciclo menstrual y su capa IA;
  # logros_comunidad bloquea el muro de celebraciones de novedades (Fase 18e).
  TIPOS = %w[tabla_posiciones ciclo_menstrual ciclo_menstrual_ia logros_comunidad].freeze
  ACCIONES = %w[otorgado revocado].freeze

  # El consentimiento NO distingue gimnasio (es por usuario y tipo) y los dos
  # que exponen a la persona ENTRE miembros — el ranking y el muro — se dieron
  # en el gimnasio donde estaba parada. Al cambiar de gimnasio (Nota 29) esos
  # dos no viajan: se revocan con esta versión de texto y el miembro vuelve a
  # optar en el nuevo si quiere. Los de ciclo son dato de salud propio, no
  # visibilidad hacia otros miembros: no dependen del gimnasio y no se tocan.
  VERSION_CAMBIO_DE_GIMNASIO = "cambio-de-gimnasio"
  TIPOS_DE_VISIBILIDAD_POR_GIMNASIO = %w[tabla_posiciones logros_comunidad].freeze

  belongs_to :user

  validates :tipo, inclusion: { in: TIPOS }
  validates :accion, inclusion: { in: ACCIONES }
  validates :version_texto, presence: true

  # Append-only a nivel de modelo, no solo de policy: una fila persistida es
  # de solo lectura — update/destroy levantan ActiveRecord::ReadOnlyRecord.
  def readonly? = persisted?

  # ¿El consentimiento está vigente? Última fila por (user, tipo) == otorgado.
  # `id` desempata filas creadas en el mismo instante (tests, doble clic).
  def self.vigente?(user, tipo)
    where(user: user, tipo: tipo).order(:created_at, :id).last&.accion == "otorgado"
  end

  # Revoca, dejando rastro append-only, los consentimientos de visibilidad
  # vigentes de la cuenta que acaba de cambiar de gimnasio. Solo escribe donde
  # había algo vigente: no ensucia el registro con revocaciones de nada.
  # Sin ip/user-agent: lo dispara el modelo, no una petición del miembro.
  def self.revocar_al_cambiar_de_gimnasio!(user)
    TIPOS_DE_VISIBILIDAD_POR_GIMNASIO.each do |tipo|
      next unless vigente?(user, tipo)

      create!(user: user, tipo: tipo, accion: "revocado",
              version_texto: VERSION_CAMBIO_DE_GIMNASIO)
    end
  end

  # Versión en lote de `vigente?` (Fase 18e): de `user_ids`, los que tienen el
  # tipo otorgado como ÚLTIMA fila — DISTINCT ON toma la más reciente por
  # usuario en una sola query.
  def self.usuarios_vigentes(tipo, user_ids)
    return [] if user_ids.blank?

    where(tipo: tipo, user_id: user_ids)
      .select("DISTINCT ON (user_id) user_id, accion")
      .order("user_id, created_at DESC, id DESC")
      .filter_map { |fila| fila.user_id if fila.accion == "otorgado" }
  end
end
