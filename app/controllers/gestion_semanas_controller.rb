# Sirve una semana del mesociclo dentro de su turbo-frame (Fase 14.9): solo la
# semana activa vive en el DOM inicial de la rutina; las demás se cargan
# perezosas al seleccionarlas en el eje. Lectura pura — autorizada con la
# policy del plan (show?): el miembro solo su plan aprobado, el staff todos.
class GestionSemanasController < ApplicationController
  def show
    # policy_scope + find (tarea 2026-08-31): una semana de un plan de otro
    # gimnasio da 404 indistinguible — el find crudo se la servía a cualquier staff.
    @plan = policy_scope(PlanPersonalizado).find(params[:plan_personalizado_id])
    authorize @plan, :show?

    @numero = params[:numero].to_i
    raise ActiveRecord::RecordNotFound unless @numero.between?(1, @plan.semanas.size)

    # editor=1: el frame viene del editor del staff (modo edición permanente)
    @editando_por_defecto = params[:editor].present? &&
                            policy(@plan).editar_rutina?

    # "La vez pasada" (Fase 14.2): UNA query para toda la semana — el partial
    # tiene prohibido consultar. Solo aplica al seguimiento del propio dueño.
    @anteriores =
      if @plan.user_id == Current.user.id
        ids = @plan.dias(semana: @numero).flat_map { |dia| Array(dia["ejercicios"]).filter_map { |ej| ej["ejercicio_id"] } }
        DetalleEntrenamiento.ultimos_por_ejercicio(Current.user, ids)
      else
        {}
      end

    render layout: false
  end
end
