# Registro append-only de consentimientos (Fase 14.11): cada otorgamiento o
# revocación es una FILA nueva con la versión del texto que el usuario aceptó,
# su IP y su user-agent — mismo espíritu auditable que `pagos`: se deja
# rastro, jamás se edita ni se borra físico. La vigencia no vive en una
# columna: es la última fila por (user, tipo).
class Consentimiento < ApplicationRecord
  # tabla_posiciones bloquea el ranking del motor de juego (Fase 14.12);
  # los de ciclo bloquean el futuro módulo de ciclo menstrual y su capa IA.
  TIPOS = %w[tabla_posiciones ciclo_menstrual ciclo_menstrual_ia].freeze
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
end
