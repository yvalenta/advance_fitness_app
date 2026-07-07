class ProgresosController < ApplicationController
  DIAS_CALORIAS = 14
  SEMANAS_ASISTENCIA = 8

  def show
    authorize :progreso, :show?
    usuario = Current.user

    # Peso: cada objetivo fijado es un snapshot con su referencia completa
    # (tipo, TDEE, kcal). Con Biometría esta serie leerá de mediciones.
    @objetivos_historial = usuario.objetivos_nutricionales.order(:created_at).to_a
    @pesos = @objetivos_historial.map { |objetivo| [ objetivo.created_at.to_date, objetivo.peso_kg.to_f ] }

    # Calorías: últimos 14 días contra el objetivo activo
    @objetivo = usuario.objetivo_activo
    desde = Date.current - (DIAS_CALORIAS - 1)
    registros = usuario.registros_calorias.where(fecha: desde..Date.current).index_by(&:fecha)
    @calorias = (desde..Date.current).map { |fecha| [ fecha, registros[fecha]&.kcal_consumidas ] }

    # Asistencia: los check-ins de cada una de las últimas 8 semanas
    inicio_semanas = Date.current.beginning_of_week - (SEMANAS_ASISTENCIA - 1).weeks
    por_semana = usuario.accesos.where(fecha_hora: inicio_semanas.beginning_of_day..)
                        .order(:fecha_hora)
                        .group_by { |acceso| acceso.fecha_hora.to_date.beginning_of_week }
    @asistencia = (0...SEMANAS_ASISTENCIA).map do |indice|
      semana = inicio_semanas + indice.weeks
      [ semana, por_semana.fetch(semana, []) ]
    end
    @visitas_mes = usuario.accesos.where(fecha_hora: Date.current.beginning_of_month.beginning_of_day..).count

    # Adherencia del mes: días registrados que cumplieron el objetivo
    del_mes = usuario.registros_calorias.where(fecha: Date.current.beginning_of_month..Date.current)
    @dias_registrados = del_mes.count
    @dias_en_meta = @objetivo ? del_mes.where(kcal_consumidas: ..@objetivo.objetivo_kcal).count : 0
  end
end
