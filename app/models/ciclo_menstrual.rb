# Registro de ciclo menstrual (Fase 14.15) — dato de salud sensible. El
# diseño de privacidad ES el entregable; reglas que este modelo asume y las
# specs blindan:
#   * Solo se crea con consentimiento `ciclo_menstrual` vigente (policy).
#   * Nadie más que la dueña lo lee — ni admin ni entrenador (policy Scope
#     sin rama de staff, único en el repo).
#   * La fase se deriva al consultar (Ciclo::Fase), nunca se persiste.
#   * Revocar el consentimiento borra las filas físicamente en la misma
#     transacción, salvo que la usuaria pida conservarlas (revocar!).
#   * El dato JAMÁS viaja al prompt de IA en esta etapa: el opt-in separado
#     `ciclo_menstrual_ia` solo queda capturado para la futura composición.
class CicloMenstrual < ApplicationRecord
  # Versiones del texto de consentimiento que la usuaria aceptó (Fase 14.11:
  # cada fila de consentimiento registra con qué texto se otorgó/revocó).
  VERSION_TEXTO = "ciclo-v1"
  VERSION_TEXTO_IA = "ciclo-ia-v1"

  belongs_to :user
  belongs_to :creado_por, class_name: "User"

  validates :fecha_inicio, presence: true,
                           uniqueness: { scope: :user_id, message: "ya tiene un ciclo registrado" }
  validates :duracion_sangrado_dias, numericality: { only_integer: true, in: 1..15 }, allow_nil: true
  validate :fecha_inicio_no_futura
  validate :fecha_fin_posterior_al_inicio

  scope :recientes, -> { order(fecha_inicio: :desc) }

  # Revoca el consentimiento de ciclo (y el de IA, si estaba vigente) y borra
  # los registros en UNA transacción: o queda el rastro de revocación Y el
  # borrado, o no queda nada a medias. Con `conservar_datos: true` solo se
  # revoca — la usuaria decide si sus registros la esperan por si vuelve.
  def self.revocar!(user, conservar_datos: false, ip: nil, user_agent: nil)
    transaction do
      { "ciclo_menstrual" => VERSION_TEXTO, "ciclo_menstrual_ia" => VERSION_TEXTO_IA }.each do |tipo, version|
        next unless Consentimiento.vigente?(user, tipo)

        user.consentimientos.create!(tipo:, accion: "revocado", version_texto: version,
                                     ip:, user_agent:)
      end
      user.ciclos_menstruales.delete_all unless conservar_datos
    end
  end

  private
    def fecha_inicio_no_futura
      return if fecha_inicio.blank? || fecha_inicio <= Date.current

      errors.add(:fecha_inicio, "no puede ser futura")
    end

    def fecha_fin_posterior_al_inicio
      return if fecha_fin.blank? || fecha_inicio.blank? || fecha_fin >= fecha_inicio

      errors.add(:fecha_fin, "debe ser igual o posterior al inicio")
    end
end
