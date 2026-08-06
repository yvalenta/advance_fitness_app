class ProgresosController < ApplicationController
  def show
    authorize :progreso, :show?
    # Fase 16.6: la página carga solo el RESUMEN — cada gráfica llega después
    # por su turbo-frame perezoso (ProgresoGraficasController).
    @progreso = ProgresoUsuario.resumen(Current.user)
    @ciclo = datos_ciclo
  end

  private

    # Datos de la card "Mi ciclo" (Fase 14.15), calculados AQUÍ y no en el
    # partial (era la única query-desde-vista del repo). Solo con
    # consentimiento vigente; la card conserva su guard defensivo de
    # privacidad (Current.user == usuario) intacto.
    def datos_ciclo
      # Feature del tenant apagada (Fase 18d) → la card no existe.
      return if Current.tenant && !Current.tenant.feature?("ciclo")
      return unless Consentimiento.vigente?(Current.user, "ciclo_menstrual")

      fase = Ciclo::Fase.para(Current.user)
      { fase: fase,
        ajuste: Ciclo::Ajuste.para(fase),
        proxima: Ciclo::Fase.proxima_menstruacion(Current.user),
        dia: Ciclo::Fase.dia_del_ciclo(Current.user),
        ciclos: Current.user.ciclos_menstruales.recientes.limit(3),
        consentimiento_ia: Consentimiento.vigente?(Current.user, "ciclo_menstrual_ia") }
    end
end
