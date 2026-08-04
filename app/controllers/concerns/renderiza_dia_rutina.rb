# Respuesta turbo_stream compartida por GestionDiasController y
# GestionEjerciciosController (Fase 6.9): tras cualquier cambio estructural
# del día (agregar/eliminar ejercicio, aplicar sesión completa), se
# reemplaza el panel sin recargar la página, dejándolo en modo edición y con
# los checks de seguimiento correctos si quien edita es el dueño del plan.
# Fase 14.9: el panel es por semana del mesociclo (dia_editor_<semana>_<indice>)
# y la fecha del seguimiento sale de Rutina::Calendario para ESA semana.
module RenderizaDiaRutina
  extend ActiveSupport::Concern

  private
    def render_dia(indice)
      semana = semana_del_dia
      dia = @plan.dias(semana: semana).fetch(indice)
      usuario = Current.user
      con_seguimiento = @plan.user_id == usuario.id
      registro = fecha = nil
      anteriores = {}

      if con_seguimiento
        fecha = Rutina::Calendario.fecha_de(@plan, semana: semana, dia_indice: indice)
        registro = usuario.registros_entrenamiento.find_by(fecha: fecha)
        # "La vez pasada" (Fase 14.2): una query para todo el día, jamás en el partial
        ids = Array(dia["ejercicios"]).map { |ejercicio| ejercicio["ejercicio_id"] }.compact
        anteriores = DetalleEntrenamiento.ultimos_por_ejercicio(usuario, ids)
      end

      render turbo_stream: turbo_stream.replace(
        "dia_editor_#{semana}_#{indice}",
        partial: "planes_personalizados/dia_editor",
        locals: { plan: @plan, dia: dia, indice: indice, semana: semana,
                  editable: true, editando_por_defecto: true,
                  con_seguimiento: con_seguimiento, registro: registro, fecha: fecha,
                  anteriores: anteriores }
      )
    end

    # La semana llega como query param en las URLs de autosave que emite
    # _dia_editor; si no viene (o viene fuera de rango) se asume la semana en
    # curso — para un plan v1 eso es siempre la semana 1.
    def semana_del_dia
      numero = params[:semana].to_i
      numero.between?(1, @plan.semanas.size) ? numero : @plan.semana_actual
    end
end
