# TMB por Mifflin-St Jeor y TDEE = TMB × factor de actividad (SDD §03).
#   Hombre: 10·peso + 6.25·talla − 5·edad + 5
#   Mujer:  10·peso + 6.25·talla − 5·edad − 161
module CalculadoraTdee
  def self.tmb(peso_kg:, talla_cm:, edad:, sexo:)
    base = (10 * peso_kg) + (6.25 * talla_cm) - (5 * edad)
    sexo == "F" ? base - 161 : base + 5
  end

  def self.tdee(peso_kg:, talla_cm:, edad:, sexo:, nivel_actividad:)
    (tmb(peso_kg:, talla_cm:, edad:, sexo:) * nivel_actividad).round
  end
end
