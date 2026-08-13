module Landing
  # Landing de autoservicio (Fase 12a, SDD §17.5): join.ynt.codes/ — un
  # entrenador o una persona individual pide entrar sin hablar antes con un
  # comercializador. Cobro manual: guardamos el lead y el staff del portal
  # comercial lo contacta por su cuenta (§Superadmin::SolicitudesAutoservicioController).
  class AutoserviciosController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verificar_pertenencia_al_tenant, raise: false

    layout "landing"

    def new
      @solicitud = SolicitudAutoservicio.new(segmento: segmento_preseleccionado)
    end

    def create
      @solicitud = SolicitudAutoservicio.new(solicitud_params)

      if @solicitud.save
        redirect_to landing_autoservicio_gracias_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def gracias
    end

    private
      def segmento_preseleccionado
        SolicitudAutoservicio::SEGMENTOS.include?(params[:segmento]) ? params[:segmento] : "entrenador"
      end

      def solicitud_params
        params.expect(solicitud_autoservicio: %i[ nombre email telefono segmento negocio_nombre mensaje ])
      end
  end
end
