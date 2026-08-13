module Landing
  # Landing de autoservicio (Fase 12b, SDD §17.5): trainer.ynt.codes y
  # entrena.ynt.codes — un entrenador o una persona individual piden entrar
  # sin hablar antes con un comercializador. Un dominio por audiencia, sin
  # toggle: el segmento sale del subdominio, nunca de un param del cliente.
  # Cobro manual: guardamos el lead y el staff del portal comercial lo
  # contacta por su cuenta (§Superadmin::SolicitudesAutoservicioController).
  class AutoserviciosController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verificar_pertenencia_al_tenant, raise: false

    layout "landing"

    SUBDOMINIO_A_SEGMENTO = { "trainer" => "entrenador", "entrena" => "individual" }.freeze

    def new
      @segmento = segmento_del_subdominio
      @solicitud = SolicitudAutoservicio.new(segmento: @segmento)
    end

    def create
      @segmento = segmento_del_subdominio
      @solicitud = SolicitudAutoservicio.new(solicitud_params.merge(segmento: @segmento))

      if @solicitud.save
        redirect_to landing_autoservicio_gracias_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def gracias
      @segmento = segmento_del_subdominio
    end

    private
      def segmento_del_subdominio
        SUBDOMINIO_A_SEGMENTO.fetch(request.subdomain, "entrenador")
      end

      def solicitud_params
        params.expect(solicitud_autoservicio: %i[ nombre email telefono negocio_nombre mensaje ])
      end
  end
end
