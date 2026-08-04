# Récord personal (Fase 14.13): la mejor marca de un usuario en un ejercicio
# del catálogo. Lo escribe únicamente Juego::DetectorPr desde el registro de
# series — nunca la UI. Un PR superado no se borra: se le marca `superado_en`
# y queda como historial (patrón pagos.anulado_en); el índice único parcial
# de la tabla garantiza UN vigente por (user, ejercicio, tipo).
class RecordPersonal < ApplicationRecord
  # peso_max:    mayor peso levantado en una serie (con al menos 1 rep).
  # volumen_max: mayor reps × peso de UNA serie.
  # reps_max:    más repeticiones a peso corporal (series sin peso_kg).
  TIPOS = %w[peso_max volumen_max reps_max].freeze

  belongs_to :user
  belongs_to :ejercicio
  # La serie que produjo la marca; optional porque el dueño puede quitar la
  # serie después (FK on_delete: :nullify) sin perder el récord.
  belongs_to :detalle_entrenamiento, optional: true

  validates :tipo, inclusion: { in: TIPOS }
  validates :valor, presence: true, numericality: { greater_than: 0 }
  validates :fecha, presence: true

  scope :vigentes, -> { where(superado_en: nil) }

  # "80 kg" / "640 kg de volumen" / "15 reps a peso corporal" — para la
  # celebración del create de series y las futuras vistas de perfil.
  def marca
    numero = valor % 1 == 0 ? valor.to_i : valor.to_f
    case tipo
    when "peso_max" then "#{numero} kg"
    when "volumen_max" then "#{numero} kg de volumen"
    else "#{numero} reps a peso corporal"
    end
  end
end
