# Modo sesión (Fase 14.3): pantalla inmersiva que guía el entrenamiento del
# día ejercicio por ejercicio con cronómetro de descanso entre series. Solo
# LEE el plan aprobado del propio usuario: el estado vive en el navegador
# (sesion_controller.js) y el "marcar día como hecho" reutiliza el endpoint
# existente de RegistrosEntrenamiento — aquí no se escribe nada.
class SesionesController < ApplicationController
  def show
    @fecha = fecha_param
    @plan = Current.user.plan_aprobado

    unless @plan
      skip_authorization # estado vacío del propio usuario: no hay record que autorizar
      return
    end

    authorize @plan, :show?
    # Composición ciclo × mesociclo (Fase 14.16): la sesión es donde la
    # prescripción se CONSUME, así que aquí los números van efectivos — la
    # semana del mesociclo de la fecha, compuesta con la fase del ciclo
    # (Rutina::Resolutor.componer clampea el factor a 0.7..1.25; la fase solo
    # baja carga). Sin consentimiento la fase es :desconocida → identidad.
    @ajuste_ciclo = Ciclo::Ajuste.para(Ciclo::Fase.para(Current.user, @fecha))
    dias_efectivos = Rutina::Resolutor.dias(@plan.rutina, numero_semana(@fecha), extra: @ajuste_ciclo)
    @dia = dia_para(@fecha, dias_efectivos)
    @ejercicios_dia = @dia ? Array(@dia["ejercicios"]) : []
    @catalogo = Ejercicio.where(id: @ejercicios_dia.filter_map { |ej| ej["ejercicio_id"] })
                         .index_by(&:id)
    @datos = datos_sesion
  end

  private

    def fecha_param
      Date.iso8601(params[:fecha].to_s)
    rescue ArgumentError
      Date.current
    end

    # Semana del mesociclo a la que pertenece la fecha (API 14.7: enteros sin
    # clamp); fuera de rango cae a la semana en curso — para un plan v1 eso
    # es siempre la 1.
    def numero_semana(fecha)
      numero = Rutina::Calendario.semana_de(@plan, fecha)
      numero.is_a?(Integer) && numero.between?(1, @plan.semanas.size) ? numero : @plan.semana_actual
    end

    # La rutina trae los días por nombre ("lunes"…"domingo"); la fecha pedida
    # se ubica por su offset desde el lunes (DIAS_OFFSET + beginning_of_week).
    # Recibe los días YA efectivos (semana + ciclo). Devuelve nil si la fecha
    # no tiene día programado (descanso).
    def dia_para(fecha, dias)
      offset = (fecha - fecha.beginning_of_week).to_i
      dias.find { |dia| PlanPersonalizado::DIAS_OFFSET[sin_acentos(dia["dia"])] == offset }
    end

    def sin_acentos(nombre)
      nombre.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip
    end

    # Datos que consume sesion_controller.js (serializados en un <script> de
    # tipo application/json): uid estable para el registro (cae al índice en
    # rutinas viejas sin uid) y series/descanso saneados para que la máquina
    # de estados nunca reciba 0 series ni descanso 0.
    def datos_sesion
      {
        fecha: @fecha.iso8601,
        dia: @dia&.fetch("dia", nil),
        enfoque: @dia&.fetch("enfoque", nil),
        ejercicios: @ejercicios_dia.each_with_index.map do |ej, indice|
          { uid: ej["uid"].presence || indice.to_s,
            indice: indice,
            nombre: ej["nombre"].to_s,
            series: [ ej["series"].to_i, 1 ].max,
            repeticiones: ej["repeticiones"].to_s,
            descanso_seg: ej["descanso_seg"].to_i.positive? ? ej["descanso_seg"].to_i : 60,
            peso_sugerido_kg: ej["peso_sugerido_kg"].to_f,
            nota_tecnica: ej["nota_tecnica"].to_s,
            ejercicio_id: (ej["ejercicio_id"] if @catalogo.key?(ej["ejercicio_id"])) }
        end
      }
    end
end
