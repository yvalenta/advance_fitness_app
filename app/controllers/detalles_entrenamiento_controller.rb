# Registro cuantitativo de series (SDD §18): feature premium sobre el
# entrenamiento del día — series reales, repeticiones, peso y RPE. El
# checkbox "hecho" del plan free/reglas (RegistrosEntrenamientoController)
# no se toca; esto es un dato adicional, exclusivo de user.premium?.
# Fase 18n: la única entrada es el POST del modo sesión (18l) — el dialog
# (GET), el quitar serie (DELETE) y su lista murieron con su UI.
class DetallesEntrenamientoController < ApplicationController
  before_action :cargar_registro_y_ejercicio, only: %i[ create ]

  def create
    authorize @registro, policy_class: DetalleEntrenamientoPolicy
    return head :unprocessable_entity unless @ejercicio

    if ActiveModel::Type::Boolean.new.cast(params[:cumplido])
      # Series idénticas entre sí: para el detector de PRs basta evaluar una
      # (misma marca de peso/volumen/reps en todas).
      detalle = DetalleEntrenamiento.registrar_cumplido!(registro: @registro, ejercicio: @ejercicio,
        series: params[:series_plan], repeticiones: params[:repeticiones_plan], peso_kg: params[:peso_kg]).first
    elsif (numero_serie = params[:serie].to_i).positive?
      # Modo sesión (Fase 18l): serie explícita e IDEMPOTENTE — el re-tap o
      # la re-visita del día no duplica (el índice único por serie respalda).
      detalle = @registro.detalles.find_by(ejercicio: @ejercicio, serie: numero_serie) ||
                @registro.detalles.create!(ejercicio: @ejercicio, serie: numero_serie,
                                           repeticiones: params[:repeticiones], peso_kg: params[:peso_kg].presence,
                                           rpe: params[:rpe].presence)
    else
      siguiente_serie = @registro.detalles.where(ejercicio: @ejercicio).maximum(:serie).to_i + 1
      detalle = @registro.detalles.create!(ejercicio: @ejercicio, serie: siguiente_serie,
                                           repeticiones: params[:repeticiones], peso_kg: params[:peso_kg].presence,
                                           rpe: params[:rpe].presence)
    end

    # Récords personales (Fase 14.13): inline y no en un job porque el
    # resultado decide la respuesta (¿hay celebración?) y cuesta una query
    # por tipo. Devuelve solo PRs reales — el baseline del primer registro
    # no celebra. La celebración se appendea al contenedor de la sesión
    # (18n): el toast es fixed y flota por encima de todo; sin récords no
    # hay nada que decir y la respuesta es un ok vacío.
    records = detalle ? Juego::DetectorPr.evaluar!(detalle) : []
    # Progresión por reglas (Fase 20d, sin IA): mismo criterio "inline, no
    # job" que el detector de PRs — es aritmética barata, no HTTP a la IA.
    if params[:uid].present?
      Progresion::Regla.evaluar_tras_serie!(user: Current.user, uid: params[:uid], fecha: @registro.fecha, ejercicio: @ejercicio)
    end
    if records.any?
      render turbo_stream: turbo_stream.append("celebraciones_sesion",
                                               partial: "shared/celebracion_pr", locals: { records: records })
    else
      head :ok
    end
  end

  # Disparador del Analista de Performance (SDD §18.4, Fase 12): solo staff
  # (ver DetalleEntrenamientoPolicy#analizar?), sobre la sesión completa de
  # un registro_entrenamiento (no un ejercicio puntual). Encola y vuelve de
  # inmediato — la IA nunca bloquea la respuesta.
  def analizar
    # policy_scope + find (tarea 2026-08-31): el find crudo dejaba al staff
    # de A encolar el Analista sobre el registro de un miembro de B (la
    # policy solo miraba user.staff?). El Scope de RegistroEntrenamiento
    # ancla por el puesto del dueño — un id ajeno da 404 indistinguible.
    @registro = policy_scope(RegistroEntrenamiento).find(params[:registro_entrenamiento_id])
    authorize @registro, policy_class: DetalleEntrenamientoPolicy

    unless @registro.user.datos_suficientes_para_analisis?
      return redirect_to admin_user_path(@registro.user),
        alert: "Aún necesita registrar series por #{User::MINIMO_SEMANAS_PARA_ANALISIS} semanas para desbloquear el análisis."
    end
    unless @registro.user.puede_analizar?
      return redirect_to admin_user_path(@registro.user),
        alert: "Ya se usó el análisis disponible para su plan; el próximo estará disponible más adelante."
    end

    feedback = @registro.feedback_ia || @registro.create_feedback_ia!(estado: "pendiente")
    feedback.marcar_generando!(origen: "manual")
    AnalizarEntrenamientoJob.perform_later(@registro.id)

    redirect_to admin_user_path(@registro.user), notice: "Análisis en curso."
  end

  private
    def cargar_registro_y_ejercicio
      fecha = Date.iso8601(params[:fecha].to_s)
      @registro = Current.user.registros_entrenamiento.find_or_create_by!(fecha: fecha)
    rescue ArgumentError
      @registro = Current.user.registros_entrenamiento.find_or_create_by!(fecha: Date.current)
    ensure
      @ejercicio = DetalleEntrenamiento.ejercicio_para(ejercicio_id: params[:ejercicio_id], nombre: params[:nombre])
    end
end
