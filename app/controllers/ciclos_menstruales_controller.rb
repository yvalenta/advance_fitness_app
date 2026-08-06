# CRUD mínimo del ciclo menstrual (Fase 14.15). Siempre en primera persona:
# todo pasa por Current.user y por policy_scope — no existe ruta, parámetro
# ni vista para que el staff registre o lea ciclos ajenos.
class CiclosMenstrualesController < ApplicationController
  before_action { exigir_feature("ciclo") }  # Fase 18d
  def create
    @ciclo = Current.user.ciclos_menstruales.new(ciclo_params.merge(creado_por: Current.user))
    authorize @ciclo # propio + consentimiento vigente (CicloMenstrualPolicy)

    if @ciclo.save
      redirect_to progreso_path, notice: "Inicio de ciclo registrado."
    else
      redirect_to progreso_path, alert: @ciclo.errors.full_messages.to_sentence
    end
  end

  def destroy
    # policy_scope antes de find: un id ajeno da 404, ni siquiera "no
    # autorizado" — no se revela que el registro existe.
    @ciclo = policy_scope(CicloMenstrual).find(params[:id])
    authorize @ciclo
    @ciclo.destroy
    redirect_to progreso_path, notice: "Registro eliminado."
  end

  private
    def ciclo_params
      params.expect(ciclo_menstrual: [ :fecha_inicio, :duracion_sangrado_dias, :nota ])
    end
end
