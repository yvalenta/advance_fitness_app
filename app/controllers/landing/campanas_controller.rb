module Landing
  class CampañasController < ApplicationController
    # Página pública de conversión — sin auth requerida
    skip_before_action :require_authentication
    # Tampoco verificar pertenencia: es una landing pública
    skip_before_action :verificar_pertenencia_al_tenant, raise: false

    layout "landing"

    before_action :cargar_campana

    def show
      # Renderiza la landing page; @campana puede ser nil si el slug no existe
    end

    def unirse
      # CTA de conversión: redirige a registro en el subdominio del tenant
      # o a la sesión si ya tiene cuenta. El tenant ya está en Current.tenant.
      if @campana
        redirect_to new_registro_url(host: "#{@campana.slug}.ynt.codes"),
                    allow_other_host: true
      else
        redirect_to root_url
      end
    end

    private

      def cargar_campana
        @campana = Current.tenant
        @slug    = Current.landing_slug || params[:slug]
      end
  end
end
