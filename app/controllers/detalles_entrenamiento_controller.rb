# Registro cuantitativo de series (SDD §18): feature premium sobre el
# entrenamiento del día — series reales, repeticiones, peso y RPE. El
# checkbox "hecho" del plan free/reglas (RegistrosEntrenamientoController)
# no se toca; esto es un dato adicional, exclusivo de user.premium?.
class DetallesEntrenamientoController < ApplicationController
  before_action :cargar_registro_y_ejercicio, only: %i[ index create ]

  # GET — contenido del turbo-frame perezoso del dialog (mismo patrón que
  # EjerciciosController#ayuda). Sin ejercicio resuelto, @ejercicio es nil y
  # la vista muestra el estado "no disponible" sin crear nada en la base.
  def index
    authorize @registro, policy_class: DetalleEntrenamientoPolicy
    @detalles = @ejercicio ? @registro.detalles.where(ejercicio: @ejercicio).order(:serie) : []
    @previa = serie_previa if @ejercicio
    @series_plan = params[:series_plan]
    @repeticiones_plan = params[:repeticiones_plan]
  end

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
    # no celebra.
    records = detalle ? Juego::DetectorPr.evaluar!(detalle) : []

    @detalles = @registro.detalles.where(ejercicio: @ejercicio).order(:serie)
    streams = [ reemplazar_lista ]
    streams << celebrar_records(records) if records.any?
    render turbo_stream: streams
  end

  # Disparador del Analista de Performance (SDD §18.4, Fase 12): solo staff
  # (ver DetalleEntrenamientoPolicy#analizar?), sobre la sesión completa de
  # un registro_entrenamiento (no un ejercicio puntual). Encola y vuelve de
  # inmediato — la IA nunca bloquea la respuesta.
  def analizar
    @registro = RegistroEntrenamiento.find(params[:registro_entrenamiento_id])
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

  # No requiere fecha/ejercicio_id en la URL: el detalle ya conoce su
  # registro y su ejercicio a través de las asociaciones.
  def destroy
    detalle = DetalleEntrenamiento.find(params[:id])
    authorize detalle

    @registro = detalle.registro_entrenamiento
    @ejercicio = detalle.ejercicio
    detalle.destroy!
    @detalles = @registro.detalles.where(ejercicio: @ejercicio).order(:serie)
    render turbo_stream: reemplazar_lista
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

    def reemplazar_lista
      turbo_stream.replace("detalles_ejercicio_#{@ejercicio.id}",
                           partial: "detalles_entrenamiento/lista",
                           locals: { registro: @registro, ejercicio: @ejercicio, detalles: @detalles,
                                     previa: serie_previa,
                                     series_plan: params[:series_plan], repeticiones_plan: params[:repeticiones_plan] })
    end

    # Prellenado del formulario (Fase 18a): la última serie de HOY si existe
    # (repetir el peso recién usado) o, si no, la de la sesión anterior del
    # mismo ejercicio — el miembro no redigita lo que la app ya sabe.
    def serie_previa
      @detalles.last || DetalleEntrenamiento.ultimos_por_ejercicio(
        Current.user, [ @ejercicio.id ], antes_de: @registro.fecha)[@ejercicio.id]
    end

    # La celebración va como SEGUNDO stream, appendeado DENTRO del mismo
    # contenedor que `reemplazar_lista` acaba de renovar — así el flujo
    # actual (replace de la lista) no cambia en nada. No se cuelga de <body>
    # porque el dialog de registro vive en el top layer de showModal() y el
    # backdrop lo taparía; dentro del dialog, el toast (fixed) sí flota
    # sobre el modal.
    def celebrar_records(records)
      turbo_stream.append("detalles_ejercicio_#{@ejercicio.id}",
                          partial: "shared/celebracion_pr", locals: { records: records })
    end
end
