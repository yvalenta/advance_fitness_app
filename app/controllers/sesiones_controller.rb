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

    # Qué toca en @fecha, con los números EFECTIVOS (Fase 14.16 + 19e): la
    # sesión es donde la prescripción se CONSUME. La resolución —
    # reprogramación, semana del mesociclo, fase del ciclo — vive en
    # PlanPersonalizado#prescripcion_de porque Progresion::Regla compara
    # contra ESTOS mismos números al registrar cada serie (Nota 27g).
    prescripcion = @plan.prescripcion_de(@fecha)
    @movido_hacia = prescripcion.movido_hacia
    @movido_desde = prescripcion.movido_desde
    @ajuste_ciclo = prescripcion.ajuste_ciclo
    @dia = prescripcion.dia
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

    # Datos que consume sesion_controller.js (serializados en un <script> de
    # tipo application/json): uid estable para el registro (cae al índice en
    # rutinas viejas sin uid) y series/descanso saneados para que la máquina
    # de estados nunca reciba 0 series ni descanso 0.
    # Fase 18l (premium): cada ejercicio lleva además el kg con el que la
    # sesión registra sus series (el sugerido del plan o, si no trae, la vez
    # pasada — ver peso_para_registrar) y cuántas series ya quedaron
    # registradas hoy — para que una re-visita pinte los chips hechos y no
    # duplique.
    def datos_sesion
      premium = Current.user.premium?
      ids = @catalogo.keys
      anteriores = premium ? DetalleEntrenamiento.ultimos_por_ejercicio(Current.user, ids, antes_de: @fecha) : {}
      registradas_hoy = premium ? series_registradas_hoy : {}

      {
        fecha: @fecha.iso8601,
        dia: @dia&.fetch("dia", nil),
        enfoque: @dia&.fetch("enfoque", nil),
        ejercicios: @ejercicios_dia.each_with_index.map do |ej, indice|
          id = (ej["ejercicio_id"] if @catalogo.key?(ej["ejercicio_id"]))
          series = [ ej["series"].to_i, 1 ].max
          { uid: ej["uid"].presence || indice.to_s,
            indice: indice,
            nombre: ej["nombre"].to_s,
            series: series,
            repeticiones: ej["repeticiones"].to_s,
            descanso_seg: ej["descanso_seg"].to_i.positive? ? ej["descanso_seg"].to_i : 60,
            peso_sugerido_kg: ej["peso_sugerido_kg"].to_f,
            nota_tecnica: ej["nota_tecnica"].to_s,
            ejercicio_id: id,
            peso_registro_kg: peso_para_registrar(anteriores[id], ej),
            series_registradas: [ registradas_hoy[id].to_i, series ].min,
            # Fase 20: tipo (reps/tiempo, para el timer de trabajo del modo
            # sesión) y grupo_superserie (dos entradas con el mismo valor no
            # descansan entre sí — sesion_controller.js las empareja por esto).
            tipo: ej["tipo"] == "tiempo" ? "tiempo" : "reps",
            grupo_superserie: ej["grupo_superserie"].presence }
        end
      }
    end

    # {ejercicio_id => series ya registradas HOY} — una query, solo premium.
    def series_registradas_hoy
      Current.user.registros_entrenamiento.find_by(fecha: @fecha)
             &.detalles&.group(:ejercicio_id)&.count || {}
    end

    # El kg que se registra es el que la pantalla MUESTRA ("≈ X kg"): el
    # sugerido EFECTIVO del día (semana del mesociclo × fase del ciclo). La
    # sesión no tiene input de peso, así que la vez pasada solo rellena
    # cuando el plan no trae número. Preferirla congelaba Progresion::Regla
    # tras su primer +2.5 (la sesión siguiente volvía a registrar el peso
    # viejo y la regla exige el sugerido exacto); tomar el máximo borraría
    # los deloads del staff y del ciclo (Nota 27f).
    def peso_para_registrar(anterior, ej)
      sugerido = ej["peso_sugerido_kg"].to_f
      return sugerido if sugerido.positive?

      anterior&.peso_kg&.to_f
    end
end
