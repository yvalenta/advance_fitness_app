class AddAnalisisASuscripcionesYFeedbackIa < ActiveRecord::Migration[8.1]
  def change
    # Nivel de análisis IA (Fase 12): mensual gratis (incluido con
    # personalizado), semanal/diario como add-on asignado a mano por staff
    # al registrar el pago, sin pasarela nueva.
    add_column :suscripciones, :analisis_tier, :string, default: "mensual", null: false

    # Distingue si un análisis lo disparó el staff manualmente o un proceso
    # automático futuro — hoy todo es manual (Fase 12: solo staff analiza).
    add_column :feedback_ia, :origen, :string, default: "manual", null: false
  end
end
