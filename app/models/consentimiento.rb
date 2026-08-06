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
