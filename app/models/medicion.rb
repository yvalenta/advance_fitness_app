class Medicion < ApplicationRecord
  # Grupos de medidas antropométricas (SDD §07, Fase 5.9). El orden es el del
  # formulario y el resumen que se manda a la IA.
  PERIMETROS = %i[cuello_cm pecho_cm cintura_cm cadera_cm brazo_cm muslo_cm pantorrilla_cm].freeze
  DIAMETROS  = %i[muneca_cm codo_cm rodilla_cm].freeze
  PLIEGUES   = %i[pliegue_tricipital_mm pliegue_subescapular_mm pliegue_suprailiaco_mm
                  pliegue_abdominal_mm pliegue_muslo_mm].freeze
  MEDIDAS = ([ :peso_kg, :talla_cm, :grasa_pct ] + PERIMETROS + DIAMETROS + PLIEGUES).freeze

  NOMBRES = {
    peso_kg: "Peso (kg)", talla_cm: "Talla (cm)", grasa_pct: "Grasa (%)",
    cuello_cm: "Cuello", pecho_cm: "Pecho", cintura_cm: "Cintura", cadera_cm: "Cadera",
    brazo_cm: "Brazo", muslo_cm: "Muslo", pantorrilla_cm: "Pantorrilla",
    muneca_cm: "Muñeca", codo_cm: "Codo", rodilla_cm: "Rodilla",
    pliegue_tricipital_mm: "Tricipital", pliegue_subescapular_mm: "Subescapular",
    pliegue_suprailiaco_mm: "Suprailíaco", pliegue_abdominal_mm: "Abdominal", pliegue_muslo_mm: "Muslo"
  }.freeze

  belongs_to :user
  belongs_to :tomada_por, class_name: "User", optional: true

  before_validation { self.fecha ||= Date.current }

  validates :fecha, presence: true, uniqueness: { scope: :user_id }
  validates :peso_kg, presence: true, numericality: { greater_than: 0 }
  (MEDIDAS - [ :peso_kg ]).each do |campo|
    validates campo, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  scope :recientes, -> { order(fecha: :desc) }

  # Pares [etiqueta, valor] presentes de un grupo, para la vista y el prompt.
  def presentes(grupo)
    grupo.filter_map { |campo| [ NOMBRES[campo], self[campo] ] if self[campo].present? }
  end
end
