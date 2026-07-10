class PlanPersonalizado < ApplicationRecord
  # generando/fallido: estados de la generación con IA antes de que exista un
  # borrador revisable (SDD §07/§10, Fase 5.7).
  ESTADOS = %w[generando borrador aprobado fallido].freeze
  EN_PROCESO = %w[generando fallido].freeze
  # "reglas" = plan sugerido incluido con la membresía (Fase 5.11): solo
  # entrenamiento, aprobado de una vez y editable por el propio miembro.
  GENERADORES = %w[ia entrenador reglas].freeze
  CAMPOS_COMIDA = %w[nombre descripcion kcal proteinas_g carbohidratos_g grasas_g].freeze
  CAMPOS_EJERCICIO = %w[nombre series repeticiones descanso_seg].freeze

  belongs_to :user
  belongs_to :aprobado_por, class_name: "User", optional: true

  validates :estado, inclusion: { in: ESTADOS }
  validates :generado_por, inclusion: { in: GENERADORES }
  validates :rutina, presence: true, unless: :en_proceso?
  # El plan sugerido por reglas es solo entrenamiento y no pasa por revisión
  validates :plan_nutricional, presence: true, unless: -> { en_proceso? || reglas? }
  validates :aprobado_por, presence: true, if: -> { aprobado? && !reglas? }

  scope :borradores, -> { where(estado: "borrador") }
  scope :aprobados, -> { where(estado: "aprobado") }
  scope :fallidos, -> { where(estado: "fallido") }
  # Lo que el entrenador debe atender en su cola
  scope :pendientes, -> { where(estado: %w[generando borrador fallido]) }

  # Turbo Streams: la cola del entrenador se actualiza en vivo (SDD §14, 5.7)
  after_create_commit :difundir_alta
  after_update_commit :difundir_cambio
  # Y el "Mi plan" del miembro se refresca en vivo cuando el staff edita un
  # plan ya publicado (SDD Fase 5.8).
  after_update_commit :difundir_a_miembro

  def borrador? = estado == "borrador"
  def aprobado? = estado == "aprobado"
  def generando? = estado == "generando"
  def fallido? = estado == "fallido"
  def en_proceso? = estado.in?(EN_PROCESO)
  def reglas? = generado_por == "reglas"

  # Plan sugerido incluido con la membresía (Fase 5.11): se crea una sola vez
  # por miembro (si no hay ya ningún plan) con la rutina de reglas según su
  # objetivo. Sin objetivo no se crea: Mi plan le pregunta la meta al miembro
  # y el plan nace al fijarla. Devuelve el plan o nil si no aplica.
  def self.asegurar_sugerido!(user)
    return if user.planes_personalizados.exists?
    return unless user.membresia&.activa?

    objetivo = user.objetivo_activo
    return unless objetivo

    create!(user: user, generado_por: "reglas", estado: "aprobado",
            rutina: GeneradorPlanBasico.para(user, objetivo: objetivo),
            plan_nutricional: {})
  end

  # ── Generación con IA ──────────────────────────────────────────────────
  def marcar_generando!
    update!(estado: "generando", error_generacion: nil)
  end

  def completar!(rutina:, plan_nutricional:, modelo:)
    update!(estado: "borrador", rutina: rutina, plan_nutricional: plan_nutricional,
            modelo_generacion: modelo, error_generacion: nil)
  end

  def fallar!(mensaje)
    update!(estado: "fallido", error_generacion: mensaje.to_s.truncate(500),
            intentos: intentos + 1)
  end

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

  # ── Rutina (SDD Fase 5.7b) — mismo patrón que las comidas pero 2D (día + ejercicio) ──
  def dias = Array(rutina["dias"])

  def ejercicios_de(dia_indice) = Array(dias.fetch(dia_indice)["ejercicios"])

  def actualizar_ejercicio!(dia_indice, ej_indice, campos)
    con_dia!(dia_indice) do |dia|
      lista = Array(dia["ejercicios"])
      lista[ej_indice] = lista.fetch(ej_indice).merge(ejercicio_saneado(campos))
      dia["ejercicios"] = lista
    end
  end

  def agregar_ejercicio!(dia_indice, campos = {})
    con_dia!(dia_indice) do |dia|
      dia["ejercicios"] = Array(dia["ejercicios"]) + [ ejercicio_saneado(campos, defaults: true) ]
    end
  end

  def eliminar_ejercicio!(dia_indice, ej_indice)
    con_dia!(dia_indice) do |dia|
      lista = Array(dia["ejercicios"])
      lista.delete_at(ej_indice) or raise ActiveRecord::RecordNotFound
      dia["ejercicios"] = lista
    end
  end

  def actualizar_enfoque!(dia_indice, texto)
    con_dia!(dia_indice) { |dia| dia["enfoque"] = texto.to_s.strip }
  end

  # Sesión completa por músculo (Fase 5.11): reemplaza el enfoque y TODOS los
  # ejercicios del día con la biblioteca de plantillas de ese músculo.
  def aplicar_sesion!(dia_indice, musculo, plantillas)
    raise ActiveRecord::RecordNotFound, "Sin plantillas para #{musculo}" if plantillas.empty?

    con_dia!(dia_indice) do |dia|
      dia["enfoque"] = PlantillaEjercicio::NOMBRES_MUSCULO.fetch(musculo, musculo.to_s.capitalize)
      dia["ejercicios"] = plantillas.map do |plantilla|
        { "nombre" => plantilla.nombre, "series" => plantilla.series || 3,
          "repeticiones" => plantilla.repeticiones, "descanso_seg" => plantilla.descanso_seg || 60 }
      end
    end
  end

  private

    # En cola del entrenador = necesita atención (generando/borrador/fallido)
    def en_cola? = estado.in?(%w[generando borrador fallido])

    def difundir_alta
      return unless en_cola?

      broadcast_prepend_to("planes_pendientes", target: "planes_pendientes",
                           partial: "entrenador/borradores/fila", locals: { plan: self })
      difundir_punto
    end

    def difundir_cambio
      if en_cola?
        broadcast_replace_to("planes_pendientes", target: self,
                             partial: "entrenador/borradores/fila", locals: { plan: self })
      else
        broadcast_remove_to("planes_pendientes", target: self)
      end
      difundir_punto
    end

    # Punto de notificación del navbar (Fase 5.11): se refresca con la cola
    def difundir_punto
      %w[punto_borradores punto_borradores_movil].each do |id|
        broadcast_replace_to("planes_pendientes", target: id,
                             partial: "shared/punto_borradores", locals: { id: id })
      end
    end

    # Solo un plan publicado es visible para el miembro; al reeditar su rutina o
    # nutrición se reemplaza su vista de "Mi plan" sin recargar. En un broadcast
    # NO hay Current.user, por eso el partial recibe `usuario:` explícito.
    def difundir_a_miembro
      return unless aprobado? && (saved_change_to_rutina? || saved_change_to_plan_nutricional?)

      broadcast_replace_to(self, target: ActionView::RecordIdentifier.dom_id(self, :mi_plan),
                           partial: "planes_personalizados/plan", locals: { plan: self, usuario: user })
    end

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

    # Muta el día indicado dentro del array jsonb y persiste la rutina completa.
    def con_dia!(dia_indice)
      lista_dias = dias
      dia = lista_dias.fetch(dia_indice)
      yield dia
      update!(rutina: rutina.merge("dias" => lista_dias))
    end

    # series/descanso enteros, repeticiones y nombre como texto.
    def ejercicio_saneado(campos, defaults: false)
      base = defaults ? { "nombre" => "Nuevo ejercicio", "series" => 3,
                          "repeticiones" => "10-12", "descanso_seg" => 60 } : {}
      campos.to_h.slice(*CAMPOS_EJERCICIO).each_with_object(base) do |(clave, valor), saneado|
        saneado[clave.to_s] = %w[nombre repeticiones].include?(clave.to_s) ? valor.to_s.strip : valor.to_i
      end
    end
end
