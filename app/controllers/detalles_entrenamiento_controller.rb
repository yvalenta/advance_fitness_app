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
    @series_plan = params[:series_plan]
    @repeticiones_plan = params[:repeticiones_plan]
  end

  def create
    authorize @registro, policy_class: DetalleEntrenamientoPolicy
    return head :unprocessable_entity unless @ejercicio

    if ActiveModel::Type::Boolean.new.cast(params[:cumplido])
      DetalleEntrenamiento.registrar_cumplido!(registro: @registro, ejercicio: @ejercicio,
        series: params[:series_plan], repeticiones: params[:repeticiones_plan], peso_kg: params[:peso_kg])
    else
      siguiente_serie = @registro.detalles.where(ejercicio: @ejercicio).maximum(:serie).to_i + 1
      @registro.detalles.create!(ejercicio: @ejercicio, serie: siguiente_serie,
                                 repeticiones: params[:repeticiones], peso_kg: params[:peso_kg].presence,
                                 rpe: params[:rpe].presence)
    end

    @detalles = @registro.detalles.where(ejercicio: @ejercicio).order(:serie)
    render turbo_stream: reemplazar_lista
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
                                     series_plan: params[:series_plan], repeticiones_plan: params[:repeticiones_plan] })
    end
end
