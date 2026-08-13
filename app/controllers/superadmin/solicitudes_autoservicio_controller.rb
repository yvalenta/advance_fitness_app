# Cola de leads del autoservicio (Fase 12a, SDD §17.5): el comercializador
# revisa lo que llega desde join.ynt.codes y lo marca atendida cuando cierra
# (o descarta) la venta a mano. El alta real del tenant/usuario sigue el
# camino de siempre por Superadmin::TenantsController — esto es solo la
# bandeja de entrada.
class Superadmin::SolicitudesAutoservicioController < ApplicationController
  before_action :cargar_solicitud, only: :update

  def index
    authorize SolicitudAutoservicio
    @solicitudes = SolicitudAutoservicio.recientes
  end

  def update
    authorize @solicitud
    @solicitud.marcar_atendida!(por: Current.user)
    redirect_to superadmin_solicitudes_autoservicio_path, notice: "Marcada como atendida."
  end

  private
    def cargar_solicitud
      @solicitud = SolicitudAutoservicio.find(params[:id])
    end
end
