# Datos de progreso (peso, calorías, asistencia) de un usuario cualquiera —
# extraído de ProgresosController (Fase 3/5.9) para reutilizarlo también en
# el dashboard del admin (Fase 6.13). PORO puro: sin acceso a sesión/Current.
module ProgresoUsuario
  DIAS_CALORIAS = 14
  SEMANAS_ASISTENCIA = 8

  Resultado = Struct.new(:pesos, :fuente_peso, :mediciones, :objetivos_historial,
                          :objetivo, :calorias, :asistencia, :visitas_mes,
                          :dias_registrados, :dias_en_meta, keyword_init: true)

  def self.para(usuario)
    # Peso: desde la Fase 5.9 la serie lee de `mediciones` (auto-registro del
    # miembro o antropometría del staff). Si aún no hay mediciones, cae al
    # snapshot de peso de cada objetivo fijado (comportamiento previo).
    mediciones = usuario.mediciones.recientes.limit(30).to_a.reverse
    if mediciones.any?
      fuente_peso = :mediciones
      objetivos_historial = []
      pesos = mediciones.map { |medicion| [ medicion.fecha, medicion.peso_kg.to_f ] }
    else
      fuente_peso = :objetivos
      objetivos_historial = usuario.objetivos_nutricionales.order(:created_at).to_a
      pesos = objetivos_historial.map { |objetivo| [ objetivo.created_at.to_date, objetivo.peso_kg.to_f ] }
    end

    # Calorías: últimos 14 días contra el objetivo activo
    objetivo = usuario.objetivo_activo
    desde = Date.current - (DIAS_CALORIAS - 1)
    registros = usuario.registros_calorias.where(fecha: desde..Date.current).index_by(&:fecha)
    calorias = (desde..Date.current).map { |fecha| [ fecha, registros[fecha]&.kcal_consumidas ] }

    # Asistencia: los check-ins de cada una de las últimas 8 semanas
    inicio_semanas = Date.current.beginning_of_week - (SEMANAS_ASISTENCIA - 1).weeks
    por_semana = usuario.accesos.where(fecha_hora: inicio_semanas.beginning_of_day..)
                        .order(:fecha_hora)
                        .group_by { |acceso| acceso.fecha_hora.to_date.beginning_of_week }
    asistencia = (0...SEMANAS_ASISTENCIA).map do |indice|
      semana = inicio_semanas + indice.weeks
      [ semana, por_semana.fetch(semana, []) ]
    end
    visitas_mes = usuario.accesos.where(fecha_hora: Date.current.beginning_of_month.beginning_of_day..).count

    # Adherencia del mes: días registrados que cumplieron el objetivo
    del_mes = usuario.registros_calorias.where(fecha: Date.current.beginning_of_month..Date.current)
    dias_registrados = del_mes.count
    dias_en_meta = objetivo ? del_mes.where(kcal_consumidas: ..objetivo.objetivo_kcal).count : 0

    Resultado.new(pesos:, fuente_peso:, mediciones:, objetivos_historial:, objetivo:, calorias:,
                  asistencia:, visitas_mes:, dias_registrados:, dias_en_meta:)
  end
end
