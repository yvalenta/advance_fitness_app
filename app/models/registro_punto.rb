# Ledger append-only del motor de juego (Fase 14.12): LA fuente de verdad de
# los puntos. `perfiles_juego` es solo una proyección reconstruible
# (Juego::Recalculador); si difieren, gana este ledger. Escribe únicamente
# Juego::Otorgador — nunca callbacks de modelos de dominio ni la UI.
class RegistroPunto < ApplicationRecord
  TIPOS = %w[checkin entrenamiento_completo racha_semanal pr logro ajuste_manual].freeze

  belongs_to :user
  # Registro que originó los puntos (Acceso, RegistroEntrenamiento, …). La
  # constraint única parcial (user, tipo, origen) hace idempotente al
  # Otorgador frente a los reintentos de ApplicationJob (retry_on
  # ConnectionNotEstablished, 5 intentos): sin ella, cada reintento en
  # ventana de deploy duplicaría puntos.
  # foreign_type: la columna del tipo va en español (origen_tipo), no el
  # origen_type que la asociación polimórfica derivaría por convención.
  belongs_to :origen, polymorphic: true, optional: true, foreign_type: :origen_tipo
  belongs_to :creado_por, class_name: "User", optional: true

  validates :tipo, inclusion: { in: TIPOS }
  validates :puntos, presence: true, numericality: { only_integer: true, other_than: 0 }
  validates :fecha, presence: true
  # Solo los ajustes manuales llevan autor humano; el resto los otorga el motor.
  validates :creado_por, presence: true, if: -> { tipo == "ajuste_manual" }

  # Append-only a nivel de modelo: una fila persistida es de solo lectura.
  def readonly? = persisted?
end
