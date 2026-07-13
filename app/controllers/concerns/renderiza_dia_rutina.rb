# Respuesta turbo_stream compartida por GestionDiasController y
# GestionEjerciciosController (Fase 6.9): tras cualquier cambio estructural
# del día (agregar/eliminar ejercicio, aplicar sesión completa), se
# reemplaza el panel sin recargar la página, dejándolo en modo edición y con
# los checks de seguimiento correctos si quien edita es el dueño del plan.
module RenderizaDiaRutina
  extend ActiveSupport::Concern

  private
    def render_dia(indice)
      dia = @plan.dias.fetch(indice)
      usuario = Current.user
      con_seguimiento = @plan.user_id == usuario.id
      registro = fecha = nil

      if con_seguimiento
        fecha = Date.current.beginning_of_week + PlanPersonalizado::DIAS_OFFSET.fetch(dia["dia"].to_s.downcase, 0)
        registro = usuario.registros_entrenamiento.find_by(fecha: fecha)
      end

      render turbo_stream: turbo_stream.replace(
        "dia_editor_#{indice}",
        partial: "planes_personalizados/dia_editor",
        locals: { plan: @plan, dia: dia, indice: indice, editable: true, editando_por_defecto: true,
                  con_seguimiento: con_seguimiento, registro: registro, fecha: fecha }
      )
    end
end
