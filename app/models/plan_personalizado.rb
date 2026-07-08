class PlanPersonalizado < ApplicationRecord
  ESTADOS = %w[borrador aprobado].freeze
  GENERADORES = %w[ia entrenador].freeze
  CAMPOS_COMIDA = %w[nombre descripcion kcal proteinas_g carbohidratos_g grasas_g].freeze

  belongs_to :user
  belongs_to :aprobado_por, class_name: "User", optional: true

  validates :estado, inclusion: { in: ESTADOS }
  validates :generado_por, inclusion: { in: GENERADORES }
  validates :rutina, :plan_nutricional, presence: true
  validates :aprobado_por, presence: true, if: :aprobado?

  scope :borradores, -> { where(estado: "borrador") }
  scope :aprobados, -> { where(estado: "aprobado") }

  def borrador? = estado == "borrador"
  def aprobado? = estado == "aprobado"

  def comidas = Array(plan_nutricional["comidas"])

  # Autosave de una comida: hace merge de los campos editados sobre la comida
  # en esa posición, preservando claves que el editor no maneja (p. ej. la
  # futura receta), y recalcula el total del día. El índice es la posición
  # en el array jsonb (no hay id por comida).
  def actualizar_comida!(indice, campos)
    lista = comidas
    original = lista.fetch(indice)
    lista[indice] = original.merge(comida_saneada(campos))
    guardar_comidas!(lista)
  end

  def agregar_comida!(campos = {})
    guardar_comidas!(comidas + [ comida_saneada(campos, defaults: true) ])
  end

  def eliminar_comida!(indice)
    lista = comidas
    lista.delete_at(indice) or raise ActiveRecord::RecordNotFound
    guardar_comidas!(lista)
  end

  # Publicar = darle visibilidad al miembro (la policy show? exige aprobado?)
  def publicar!(staff)
    update!(estado: "aprobado", aprobado_por: staff)
  end

  private

    def guardar_comidas!(lista)
      update!(plan_nutricional: plan_nutricional.merge(
        "comidas" => lista,
        "kcal_diarias" => lista.sum { |comida| comida["kcal"].to_i }
      ))
    end

    # Solo claves conocidas; kcal/macros como número (evita "45.0" o basura)
    def comida_saneada(campos, defaults: false)
      base = defaults ? { "nombre" => "Nueva comida", "descripcion" => "", "kcal" => 0,
                          "proteinas_g" => 0, "carbohidratos_g" => 0, "grasas_g" => 0 } : {}
      campos.to_h.slice(*CAMPOS_COMIDA).each_with_object(base) do |(clave, valor), saneada|
        saneada[clave.to_s] = clave.to_s == "descripcion" || clave.to_s == "nombre" ? valor.to_s.strip : como_numero(valor)
      end
    end

    def como_numero(texto)
      numero = texto.to_f
      (numero % 1).zero? ? numero.to_i : numero.round(1)
    end
end
