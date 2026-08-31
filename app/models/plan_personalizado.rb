class PlanPersonalizado < ApplicationRecord
  # generando/fallido: estados de la generación con IA antes de que exista un
  # borrador revisable (SDD §07/§10, Fase 5.7).
  ESTADOS = %w[generando borrador aprobado fallido].freeze
  EN_PROCESO = %w[generando fallido].freeze
  # "reglas" = plan sugerido incluido con la membresía (Fase 5.11): solo
  # entrenamiento, aprobado de una vez y editable por el propio miembro.
  GENERADORES = %w[ia entrenador reglas].freeze
  CAMPOS_COMIDA = %w[nombre descripcion kcal proteinas_g carbohidratos_g grasas_g tipo].freeze
  # ejercicio_id enlaza al catálogo visual (Fase 6); peso_sugerido_kg y
  # nota_tecnica los personaliza la IA con catálogo cerrado (Fase 6.5).
  # uid (Fase 14.6): identidad estable POR ENTRADA del array (dos "Press banca"
  # el mismo día llevan uids distintos) — el seguimiento se ancla a él y ya no
  # se re-atribuye si el plan cambia de orden.
  # Fase 20: tipo ("reps" default, ausente = reps · "tiempo" reusa
  # `repeticiones` como segundos — plancha, dead hang), unilateral (reps por
  # lado en la lectura, el total se sigue registrando igual) y
  # grupo_superserie (dos entradas con el MISMO valor no descansan entre
  # ellas en el modo sesión, solo tras completar el par). Ninguno lo escribe
  # la IA (fuera del prompt/validador a propósito, Nota 27) — son ajuste
  # manual del staff sobre un plan ya generado.
  CAMPOS_EJERCICIO = %w[nombre series repeticiones descanso_seg ejercicio_id peso_sugerido_kg nota_tecnica uid
                        tipo unilateral grupo_superserie].freeze
  TIPOS_EJERCICIO = %w[reps tiempo].freeze
  # Día de la semana (nombre en rutina["dias"]) → offset desde el lunes, para
  # ubicar el RegistroEntrenamiento de la semana actual (Fase 5.10/6.9).
  DIAS_OFFSET = { "lunes" => 0, "martes" => 1, "miercoles" => 2, "jueves" => 3,
                  "viernes" => 4, "sabado" => 5, "domingo" => 6 }.freeze
  # Contrato `rutina` v2 con mesociclo (Fase 14.7): rutina["dias"] pasa a ser
  # la plantilla base y rutina["semanas"] la modula por copy-on-write (una
  # semana con "dias" => nil hereda la base aplicando su "ajuste").
  VERSION_MESOCICLO = 2
  CAMPOS_AJUSTE = %w[series_delta peso_factor reps_delta].freeze
  RANGO_PESO_FACTOR = (0.5..1.5)
  RANGO_DELTAS = (-2..2)

  belongs_to :user
  belongs_to :aprobado_por, class_name: "User", optional: true
  has_many :reprogramaciones_dia, dependent: :destroy

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
  # Planes cuyo DUEÑO tiene puesto en el gimnasio — el mismo criterio de
  # pertenencia que ApplicationPolicy::Scope#del_tenant (puestos, no la cache
  # users.tenant_id). Con tenant nil devuelve vacío: fail-closed, igual que
  # las policies. Lo usa el punto de borradores del navbar, que se renderiza
  # también desde broadcasts donde no existe Current.user.
  scope :del_tenant, ->(tenant) { where(user_id: Puesto.where(tenant_id: tenant).select(:user_id)) }
  # Un plan real tarda segundos; más de esto casi siempre es un worker que
  # murió a mitad de camino (p. ej. un deploy) sin dejar rastro del error.
  MINUTOS_ANTES_DE_ESTANCARSE = 10
  scope :estancados, -> { where(estado: "generando").where(updated_at: ...MINUTOS_ANTES_DE_ESTANCARSE.minutes.ago) }

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
            rutina: rutina_con_inicio(GeneradorPlanBasico.para(user, objetivo: objetivo)),
            plan_nutricional: {})
  end

  # Fija mesociclo["inicio"] al lunes de la semana de `fecha` — el calendario
  # (Rutina::Calendario) arranca cuando el plan se le entrega al miembro.
  # Una rutina v1 (sin "version") vuelve tal cual: no se le inventa mesociclo.
  def self.rutina_con_inicio(rutina, fecha = Date.current)
    return rutina unless rutina.is_a?(Hash) && rutina["version"].to_i >= VERSION_MESOCICLO

    mesociclo = (rutina["mesociclo"] || {}).merge("inicio" => fecha.beginning_of_week.iso8601)
    rutina.merge("mesociclo" => mesociclo)
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

  # Publicar = darle visibilidad al miembro (la policy show? exige aprobado?).
  # En un contrato v2 además (re)arranca el calendario: el mesociclo inicia
  # el lunes de la semana en que se publica.
  def publicar!(staff)
    update!(estado: "aprobado", aprobado_por: staff,
            rutina: self.class.rutina_con_inicio(rutina))
  end

  # ── Rutina (SDD Fase 5.7b) — mismo patrón que las comidas pero 2D (día + ejercicio) ──
  # Sin `semana:` devuelve la plantilla base (comportamiento histórico); con
  # `semana: n` devuelve los días EFECTIVOS de esa semana del mesociclo
  # (Rutina::Resolutor: herencia base + ajuste, o la copia materializada).
  def dias(semana: nil)
    return Array(rutina["dias"]) if semana.nil?

    Rutina::Resolutor.dias(rutina_normalizada, semana)
  end

  def ejercicios_de(dia_indice, semana: nil) = Array(dias(semana: semana).fetch(dia_indice)["ejercicios"])

  def actualizar_ejercicio!(dia_indice, ej_indice, campos, semana: nil)
    con_dia!(dia_indice, semana: semana) do |dia|
      lista = Array(dia["ejercicios"])
      lista[ej_indice] = lista.fetch(ej_indice).merge(ejercicio_saneado(campos))
      dia["ejercicios"] = lista
    end
  end

  def agregar_ejercicio!(dia_indice, campos = {}, semana: nil)
    con_dia!(dia_indice, semana: semana) do |dia|
      dia["ejercicios"] = Array(dia["ejercicios"]) + [ ejercicio_saneado(campos, defaults: true) ]
    end
  end

  def eliminar_ejercicio!(dia_indice, ej_indice, semana: nil)
    con_dia!(dia_indice, semana: semana) do |dia|
      lista = Array(dia["ejercicios"])
      lista.delete_at(ej_indice) or raise ActiveRecord::RecordNotFound
      dia["ejercicios"] = lista
    end
  end

  def actualizar_enfoque!(dia_indice, texto, semana: nil)
    con_dia!(dia_indice, semana: semana) { |dia| dia["enfoque"] = texto.to_s.strip }
  end

  # Sesión completa por músculo (Fase 5.11): reemplaza el enfoque y TODOS los
  # ejercicios del día con la biblioteca de plantillas de ese músculo.
  def aplicar_sesion!(dia_indice, musculo, plantillas, semana: nil)
    raise ActiveRecord::RecordNotFound, "Sin plantillas para #{musculo}" if plantillas.empty?

    con_dia!(dia_indice, semana: semana) do |dia|
      dia["enfoque"] = PlantillaEjercicio::NOMBRES_MUSCULO.fetch(musculo, musculo.to_s.capitalize)
      dia["ejercicios"] = plantillas.map do |plantilla|
        { "nombre" => plantilla.nombre, "series" => plantilla.series || 3,
          "repeticiones" => plantilla.repeticiones, "descanso_seg" => plantilla.descanso_seg || 60,
          "ejercicio_id" => plantilla.ejercicio_id,
          "uid" => SecureRandom.alphanumeric(10) }.compact
      end
    end
  end

  # ── Mesociclo (contrato rutina v2, Fase 14.7) ──────────────────────────
  # Toda la lectura pasa por `rutina_normalizada`: un plan v1 se ve como un
  # mesociclo sintético de 1 semana identidad SIN escribir nada.
  def semanas = Array(rutina_normalizada["semanas"])

  def semana(numero) = semanas.find { |sem| sem["numero"] == numero }

  def semanas_total
    total = rutina_normalizada.dig("mesociclo", "semanas_total").to_i
    total.positive? ? total : [ semanas.size, 1 ].max
  end

  # Semana del mesociclo en la que estamos hoy, con clamp a 1..semanas_total:
  # antes del inicio se entrena la semana 1; terminado el ciclo, la última.
  def semana_actual = Rutina::Calendario.semana_de(self, Date.current).clamp(1, semanas_total)

  def mesociclo_completado? = Rutina::Calendario.semana_de(self, Date.current) > semanas_total

  def semana_materializada?(numero)
    sem = semana(numero)
    sem.present? && !sem["dias"].nil?
  end

  # Congela la semana como copia independiente de la base (copy-on-write):
  # días resueltos con su ajuste ya horneado, listos para edición estructural.
  # Los ejercicios conservan TODAS sus claves — uid incluido —: base y semana
  # comparten uid porque son el MISMO ejercicio (el uid identifica al
  # ejercicio a través del mesociclo, no a una copia por semana). Idempotente:
  # una semana ya materializada no se toca. Sobre un plan v1 la primera
  # mutación semanal persiste la estructura v2 (la lectura jamás escribe).
  def materializar_semana!(numero)
    return self if semana_materializada?(numero)

    con_semana!(numero) do |sem, norm|
      sem["dias"] = Rutina::Resolutor.dias(norm, numero)
    end
  end

  # Vuelve la semana a herencia base + ajuste, descartando sus ediciones
  # estructurales (es la operación inversa y con pérdida deliberada).
  def desmaterializar_semana!(numero)
    return self unless semana_materializada?(numero)

    con_semana!(numero) { |sem, _norm| sem["dias"] = nil }
  end

  # Merge de campos del ajuste (solo CAMPOS_AJUSTE, con clamps) preservando
  # lo que no venga — mismo patrón de saneo que ejercicio_saneado.
  def actualizar_ajuste_semana!(numero, campos)
    con_semana!(numero) do |sem, _norm|
      sem["ajuste"] = (sem["ajuste"] || {}).merge(ajuste_saneado(campos))
    end
  end

  # Reprogramar un día (Fase 19e): `fecha` dejó de tener contenido propio
  # porque se movió a otra — SesionesController la muestra como movida.
  def movido_hacia(fecha)
    reprogramaciones_dia.find_by(fecha_original: fecha)
  end

  # `fecha` muestra el contenido de OTRA fecha que se movió hacia ella.
  def movido_desde(fecha)
    reprogramaciones_dia.find_by(fecha_destino: fecha)
  end

  private

    # En cola del entrenador = necesita atención (generando/borrador/fallido)
    def en_cola? = estado.in?(%w[generando borrador fallido])

    # Gimnasios donde el DUEÑO del plan tiene puesto — los mismos cuyo staff
    # ve este plan en su cola (policy_scope vía del_tenant). El stream
    # "planes_pendientes" va namespaceado por tenant (tarea 2026-08-31): sin
    # el par, los turbo streams de un gimnasio llegaban a los navegadores del
    # staff de TODOS los demás. En un broadcast no hay Current: el tenant
    # sale del dueño, jamás del request.
    def tenants_del_duenio = Tenant.where(id: user.puestos.select(:tenant_id))

    def difundir_alta
      return unless en_cola?

      tenants_del_duenio.each do |tenant|
        broadcast_prepend_to(tenant, "planes_pendientes", target: "planes_pendientes",
                             partial: "entrenador/borradores/fila", locals: { plan: self })
        difundir_punto(tenant)
      end
    end

    def difundir_cambio
      tenants_del_duenio.each do |tenant|
        if en_cola?
          broadcast_replace_to(tenant, "planes_pendientes", target: self,
                               partial: "entrenador/borradores/fila", locals: { plan: self })
        else
          broadcast_remove_to(tenant, "planes_pendientes", target: self)
        end
        difundir_punto(tenant)
      end
    end

    # Punto de notificación del navbar (Fase 5.11): se refresca con la cola.
    # El partial recibe `tenant:` explícito para contar SOLO los pendientes
    # de ese gimnasio (acá no hay Current del que colgarse).
    def difundir_punto(tenant)
      %w[punto_borradores punto_borradores_movil].each do |id|
        broadcast_replace_to(tenant, "planes_pendientes", target: id,
                             partial: "shared/punto_borradores", locals: { id: id, tenant: tenant })
      end
    end

    # Solo un plan publicado es visible para el miembro; si el STAFF reedita
    # su rutina o nutrición se reemplaza su vista de "Mi plan" sin recargar.
    # Si el cambio lo hizo el propio dueño (Fase 12.1: ya puede editar su
    # nutrición), NO se difunde: su respuesta directa ya actualizó su vista,
    # y este broadcast de página completa le resetearía el toggle de edición
    # a mitad de una sesión de guardado. En un broadcast NO hay Current.user,
    # por eso el partial recibe `usuario:` explícito.
    def difundir_a_miembro
      return unless aprobado? && (saved_change_to_rutina? || saved_change_to_plan_nutricional?)
      return if Current.user&.id == user_id

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

    # Muta el día indicado dentro del array jsonb y persiste la rutina
    # completa. Sin `semana:` opera sobre la plantilla base (comportamiento
    # histórico, idéntico para planes v1). Con `semana: n` el cambio es
    # estructural PARA ESA SEMANA: la materializa si hace falta y muta su
    # copia, dejando la base y las demás semanas intactas.
    def con_dia!(dia_indice, semana: nil)
      if semana
        materializar_semana!(semana)
        con_semana!(semana) do |sem, _norm|
          yield sem["dias"].fetch(dia_indice)
        end
      else
        lista_dias = dias
        dia = lista_dias.fetch(dia_indice)
        yield dia
        update!(rutina: rutina.merge("dias" => lista_dias))
      end
    end

    # Lectura tolerante (Fase 14.7): un plan v1 se ve EN MEMORIA como un
    # mesociclo de 1 semana identidad; desde la lectura jamás se escribe.
    # "Declara v2" usa el MISMO predicado que Ejercicios::ValidadorRutina
    # (version, mesociclo o semanas presentes — integración 14.7+14.8): una
    # rutina escrita a mano desde el editor JSON del staff con "semanas" pero
    # sin "version" también es v2, y las piezas que falten se completan en
    # memoria con los mismos defaults. El inicio sintético es el lunes de la
    # semana de creación — el mismo fallback que usa Rutina::Calendario.
    def rutina_normalizada
      base = rutina.is_a?(Hash) ? rutina : {}
      semanas_declaradas = base["semanas"].is_a?(Array) ? base["semanas"] : []
      declarada_v2 = base["version"].to_i >= VERSION_MESOCICLO ||
                     base["mesociclo"].is_a?(Hash) || semanas_declaradas.any?

      unless declarada_v2
        semanas_declaradas = [ { "numero" => 1, "etiqueta" => "Semana 1", "descarga" => false,
                                 "ajuste" => Rutina::Resolutor::AJUSTE_IDENTIDAD.dup, "dias" => nil } ]
      end

      mesociclo = base["mesociclo"].is_a?(Hash) ? base["mesociclo"] : {}
      base.merge(
        "version" => VERSION_MESOCICLO,
        "mesociclo" => {
          "nombre" => "Mesociclo", "semanas_total" => semanas_declaradas.size,
          "inicio" => (created_at || Time.current).to_date.beginning_of_week.iso8601,
          "progresion" => "lineal"
        }.merge(mesociclo.compact),
        "semanas" => semanas_declaradas
      )
    end

    # Muta la semana indicada dentro de la rutina v2 y persiste. Si el plan
    # aún es v1, esta primera escritura semanal "asciende" el contrato: se
    # persiste la normalización (mesociclo sintético de 1 semana identidad,
    # con inicio ya fijado para que el calendario no dependa de created_at).
    def con_semana!(numero)
      norm = rutina_normalizada.deep_dup
      lista = Array(norm["semanas"])
      sem = lista.find { |s| s["numero"] == numero } or
        raise ActiveRecord::RecordNotFound, "Semana #{numero} no existe en el mesociclo"

      yield sem, norm
      update!(rutina: norm.merge("semanas" => lista))
      self
    end

    # Solo claves conocidas del ajuste, con tipos y rangos seguros: deltas
    # enteros en -2..2 y peso_factor en 0.5..1.5 (dos decimales, sin ".0").
    def ajuste_saneado(campos)
      campos.to_h.slice(*CAMPOS_AJUSTE).each_with_object({}) do |(clave, valor), saneado|
        saneado[clave.to_s] =
          if clave.to_s == "peso_factor"
            factor = valor.to_f.clamp(RANGO_PESO_FACTOR).round(2)
            (factor % 1).zero? ? factor.to_i : factor
          else
            valor.to_i.clamp(RANGO_DELTAS)
          end
      end
    end

    # series/descanso enteros, repeticiones y nombre como texto.
    def ejercicio_saneado(campos, defaults: false)
      base = defaults ? { "nombre" => "Nuevo ejercicio", "series" => 3,
                          "repeticiones" => "10-12", "descanso_seg" => 60,
                          "uid" => SecureRandom.alphanumeric(10) } : {}
      campos.to_h.slice(*CAMPOS_EJERCICIO).each_with_object(base) do |(clave, valor), saneado|
        # uid (Fase 14.6): se preserva tal cual si viene con valor (el autosave
        # reenvía todo); si viene en blanco NO entra al merge, así el hash
        # original conserva el suyo — la identidad jamás se borra por accidente.
        if clave.to_s == "uid"
          limpio = valor.to_s.strip
          saneado["uid"] = limpio if limpio.present?
          next
        end

        saneado[clave.to_s] =
          case clave.to_s
          when "nombre", "repeticiones", "nota_tecnica", "grupo_superserie" then valor.to_s.strip
          when "ejercicio_id" then valor.presence && valor.to_i
          when "peso_sugerido_kg" then valor.presence && como_numero(valor)
          when "tipo" then TIPOS_EJERCICIO.include?(valor.to_s) ? valor.to_s : "reps"
          when "unilateral" then valor.to_s == "1" || valor == true
          else valor.to_i
          end
      end
    end
end
