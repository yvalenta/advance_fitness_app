# Objetivo kcal según la meta (SDD §03):
#   deficit:       TDEE − 500
#   mantenimiento: TDEE
#   superavit:     TDEE + 300..500 según somatotipo — el ectomorfo (dificultad
#                  para ganar masa) necesita el excedente mayor.
module ObjetivoCalorico
  DEFICIT = 500
  SUPERAVIT_POR_SOMATOTIPO = {
    "ectomorfo" => 500,
    "mesomorfo" => 400,
    "endomorfo" => 300
  }.freeze
  SUPERAVIT_DEFAULT = 400

  def self.kcal(tdee:, tipo:, somatotipo: nil)
    case tipo
    when "deficit" then tdee - DEFICIT
    when "superavit" then tdee + superavit_para(somatotipo)
    else tdee
    end
  end

  def self.superavit_para(somatotipo)
    SUPERAVIT_POR_SOMATOTIPO.fetch(somatotipo, SUPERAVIT_DEFAULT)
  end
end
