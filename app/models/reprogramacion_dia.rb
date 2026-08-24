# Mueve el entrenamiento de `fecha_original` a `fecha_destino` sin tocar la
# plantilla semanal del plan (Fase 19e). Sesiones (SesionesController) la
# consulta para saber qué contenido mostrar en cada fecha:
#   - `fecha_original` deja de tener contenido propio (se movió).
#   - `fecha_destino` muestra el contenido que tenía `fecha_original`.
class ReprogramacionDia < ApplicationRecord
  belongs_to :plan_personalizado

  validates :fecha_original, :fecha_destino, presence: true
  validates :fecha_original, uniqueness: { scope: :plan_personalizado_id }
  validates :fecha_destino, uniqueness: { scope: :plan_personalizado_id }
  validate :destino_distinto_del_origen
  validate :fechas_no_encadenan_otra_reprogramacion

  private
    def destino_distinto_del_origen
      return if fecha_destino.blank? || fecha_original.blank? || fecha_destino != fecha_original

      errors.add(:fecha_destino, "debe ser distinta a la fecha original")
    end

    # Sin encadenar: el origen no puede ser ya el destino de OTRA
    # reprogramación, ni el destino puede ser ya el origen de otra — un día
    # solo se mueve una vez, no se arma una cadena de traslados.
    def fechas_no_encadenan_otra_reprogramacion
      return if plan_personalizado_id.blank?

      otras = plan_personalizado.reprogramaciones_dia.where.not(id: id)
      if fecha_original.present? && otras.exists?(fecha_destino: fecha_original)
        errors.add(:fecha_original, "ya recibió el entrenamiento de otro día movido")
      end
      if fecha_destino.present? && otras.exists?(fecha_original: fecha_destino)
        errors.add(:fecha_destino, "ya se movió a otra fecha")
      end
    end
end
