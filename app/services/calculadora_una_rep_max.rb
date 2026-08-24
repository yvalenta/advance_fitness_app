# 1RM estimado por la fórmula de Epley (SDD §05: services puros, sin BD).
#   1RM = peso × (1 + reps / 30)
# Por encima de REPS_MAXIMAS el error de la fórmula crece demasiado para ser
# útil — no se estima (mismo límite que usan trackers de referencia).
module CalculadoraUnaRepMax
  REPS_MAXIMAS = 12

  def self.estimar(peso_kg:, repeticiones:)
    return nil if peso_kg.blank? || repeticiones.blank?
    return nil if repeticiones < 1 || repeticiones > REPS_MAXIMAS

    (peso_kg * (1 + (repeticiones / 30.0))).round(1)
  end
end
