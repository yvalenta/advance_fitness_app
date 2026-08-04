# Datos de progreso (peso, calorías, asistencia) de un usuario cualquiera —
# extraído de ProgresosController (Fase 3/5.9) para reutilizarlo también en
# el dashboard del admin (Fase 6.13). PORO puro: sin acceso a sesión/Current.
#
# Particionado en SECCIONES (Fase 16.6): la página del miembro carga solo el
# resumen y cada gráfica llega después por su turbo-frame perezoso con SU
# sección (`.seccion`). `.para` compone las cuatro — admin/users/show sigue
# recibiendo el Resultado completo sin enterarse del cambio.
module ProgresoUsuario
  DIAS_CALORIAS = 14
  SEMANAS_ASISTENCIA = 8

  FEEDBACKS_MAX = 10

  SECCIONES_GRAFICA = %w[peso calorias asistencia].freeze

  Resultado = Struct.new(:pesos, :fuente_peso, :mediciones, :objetivos_historial,
                          :objetivo, :calorias, :asistencia, :visitas_mes,
                          :dias_registrados, :dias_en_meta, :feedbacks_ia, keyword_init: true)

  def self.para(usuario)
    calorias = seccion_calorias(usuario)
    Resultado.new(**seccion_pesos(usuario), **calorias, **seccion_asistencia(usuario),
                  **seccion_resumen(usuario, objetivo: calorias[:objetivo]))
  end

  # La página del miembro: cards superiores + form de peso + historial de
  # mediciones + adherencia — sin las series de calorías/asistencia (van en
  # sus frames). El objetivo sí viaja (la card de adherencia lo necesita).
  def self.resumen(usuario)
    objetivo = usuario.objetivo_activo
    Resultado.new(**seccion_pesos(usuario), objetivo: objetivo,
                  **seccion_resumen(usuario, objetivo: objetivo))
  end

  # Una sección de gráfica para su turbo-frame (Fase 16.6). El Resultado
  # parcial deja en nil lo que la gráfica no lee — los partials solo tocan
  # los miembros de su sección.
  def self.seccion(usuario, tipo)
    case tipo
    when "peso" then Resultado.new(**seccion_pesos(usuario))
    when "calorias" then Resultado.new(**seccion_calorias(usuario))
    when "asistencia" then Resultado.new(**seccion_asistencia(usuario))
    end
  end

  # ── Secciones (hashes componibles) ──────────────────────────────────────

  # Peso: desde la Fase 5.9 la serie lee de `mediciones` (auto-registro del
  # miembro o antropometría del staff). Si aún no hay mediciones, cae al
  # snapshot de peso de cada objetivo fijado (comportamiento previo).
  def self.seccion_pesos(usuario)
    mediciones = usuario.mediciones.recientes.limit(30).to_a.reverse
    if mediciones.any?
      { fuente_peso: :mediciones, mediciones: mediciones, objetivos_historial: [],
        pesos: mediciones.map { |medicion| [ medicion.fecha, medicion.peso_kg.to_f ] } }
    else
      historial = usuario.objetivos_nutricionales.order(:created_at).to_a
      { fuente_peso: :objetivos, mediciones: mediciones, objetivos_historial: historial,
        pesos: historial.map { |objetivo| [ objetivo.created_at.to_date, objetivo.peso_kg.to_f ] } }
    end
  end

  # Calorías: últimos 14 días contra el objetivo activo
  def self.seccion_calorias(usuario)
    desde = Date.current - (DIAS_CALORIAS - 1)
    registros = usuario.registros_calorias.where(fecha: desde..Date.current).index_by(&:fecha)
    { objetivo: usuario.objetivo_activo,
      calorias: (desde..Date.current).map { |fecha| [ fecha, registros[fecha]&.kcal_consumidas ] } }
  end

  # Asistencia: los check-ins de cada una de las últimas 8 semanas
  def self.seccion_asistencia(usuario)
    inicio = Date.current.beginning_of_week - (SEMANAS_ASISTENCIA - 1).weeks
    por_semana = usuario.accesos.where(fecha_hora: inicio.beginning_of_day..)
                        .order(:fecha_hora)
                        .group_by { |acceso| acceso.fecha_hora.to_date.beginning_of_week }
    { asistencia: (0...SEMANAS_ASISTENCIA).map { |indice| [ inicio + indice.weeks, por_semana.fetch(inicio + indice.weeks, []) ] } }
  end

  # Visitas del mes, adherencia y el historial del Analista (Fase 12)
  def self.seccion_resumen(usuario, objetivo:)
    del_mes = usuario.registros_calorias.where(fecha: Date.current.beginning_of_month..Date.current)
    { visitas_mes: usuario.accesos.where(fecha_hora: Date.current.beginning_of_month.beginning_of_day..).count,
      dias_registrados: del_mes.count,
      dias_en_meta: objetivo ? del_mes.where(kcal_consumidas: ..objetivo.objetivo_kcal).count : 0,
      feedbacks_ia: usuario.registros_entrenamiento
                           .joins(:feedback_ia).where(feedback_ia: { estado: "listo" })
                           .includes(:feedback_ia).order(fecha: :desc).limit(FEEDBACKS_MAX) }
  end

  private_class_method :seccion_pesos, :seccion_calorias, :seccion_asistencia, :seccion_resumen
end
