# Sirve una semana del mesociclo dentro de su turbo-frame (Fase 14.9): solo la
# semana activa vive en el DOM inicial de la rutina; las demás se cargan
# perezosas al seleccionarlas en el eje. Lectura pura — autorizada con la
# policy del plan (show?): el miembro solo su plan aprobado, el staff todos.
class GestionSemanasController < ApplicationController
  def show
    @plan = PlanPersonalizado.find(params[:plan_personalizado_id])
    authorize @plan, :show?

    @numero = params[:numero].to_i
    raise ActiveRecord::RecordNotFound unless @numero.between?(1, @plan.semanas.size)

    # editor=1: el frame viene del editor del staff (modo edición permanente)
    @editando_por_defecto = params[:editor].present? &&
                            policy(@plan).editar_rutina?

    render layout: false
  end
end
