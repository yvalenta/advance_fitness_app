class ProgresosController < ApplicationController
  DIAS_CALORIAS = 14
  SEMANAS_ASISTENCIA = 8

  def show
    authorize :progreso, :show?
    usuario = Current.user

    # Peso: snapshots de cada objetivo fijado (con Biometría leerá mediciones)
    @pesos = usuario.objetivos_nutricionales.order(:created_at)
                    .pluck(:created_at, :peso_kg)
                    .map { |fecha, peso| [ fecha.to_date, peso.to_f ] }

    # Calorías: últimos 14 días contra el objetivo activo
    @objetivo = usuario.objetivo_activo
    desde = Date.current - (DIAS_CALORIAS - 1)
    registros = usuario.registros_calorias.where(fecha: desde..Date.current).index_by(&:fecha)
    @calorias = (desde..Date.current).map { |fecha| [ fecha, registros[fecha]&.kcal_consumidas ] }

    # Asistencia: check-ins por semana (últimas 8) y total del mes
    inicio_semanas = Date.current.beginning_of_week - (SEMANAS_ASISTENCIA - 1).weeks
    por_semana = usuario.accesos.where(fecha_hora: inicio_semanas.beginning_of_day..)
                        .group_by { |acceso| acceso.fecha_hora.to_date.beginning_of_week }
    @asistencia = (0...SEMANAS_ASISTENCIA).map do |indice|
      semana = inicio_semanas + indice.weeks
      [ semana, por_semana.fetch(semana, []).size ]
    end
    @visitas_mes = usuario.accesos.where(fecha_hora: Date.current.beginning_of_month.beginning_of_day..).count

    # Adherencia del mes: días registrados que cumplieron el objetivo
    del_mes = usuario.registros_calorias.where(fecha: Date.current.beginning_of_month..Date.current)
    @dias_registrados = del_mes.count
    @dias_en_meta = @objetivo ? del_mes.where(kcal_consumidas: ..@objetivo.objetivo_kcal).count : 0
  end
end
