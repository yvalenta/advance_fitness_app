# Panel Admin → Funcionalidades (Fase 18d): toggles del admin del tenant
# sobre `tenant.features_habilitadas`. Apagar una feature esconde sus links y
# cierra sus rutas (`exigir_feature`) — JAMÁS borra datos: reencender trae
# todo de vuelta. Solo el admin del propio tenant (TenantPolicy).
class Admin::FuncionalidadesController < ApplicationController
  # [nombre, descripción] por llave — el orden es el del panel.
  FEATURES = {
    "membresias" => [ "Membresías y pagos", "Check-in, membresías, pagos y renovaciones presenciales." ],
    "nutricion" => [ "Nutrición", "Objetivo calórico, registro de consumo y plan de comidas." ],
    "gamificacion" => [ "Rachas y ranking", "Puntos, logros y tabla de posiciones opt-in." ],
    "ciclo" => [ "Ciclo menstrual", "Registro del ciclo con consentimiento y ajustes por fase." ],
    "blog" => [ "Blog", "Artículos del gimnasio para los miembros." ],
    "novedades" => [ "Novedades y comunidad", "Anuncios del staff y muro de logros de los miembros." ]
  }.freeze

  def show
    @tenant = tenant_del_admin
    authorize @tenant, :funcionalidades?
  end

  def update
    @tenant = tenant_del_admin
    authorize @tenant, :funcionalidades?

    @tenant.update!(features_habilitadas: features_recibidas)
    redirect_to admin_funcionalidades_path, notice: "Funcionalidades actualizadas."
  end

  private
    # Sin tenant (portal comercial) el panel no existe.
    def tenant_del_admin
      Current.tenant || raise(ActiveRecord::RecordNotFound)
    end

    # Todas las llaves conocidas viajan explícitas (checkbox + hidden 0);
    # cualquier otra clave del jsonb se conserva tal cual.
    def features_recibidas
      marcadas = params.expect(funcionalidades: Tenant::FEATURES.map(&:to_sym))
      @tenant.features_habilitadas.merge(
        Tenant::FEATURES.index_with { |clave| marcadas[clave] == "1" }
      )
    end
end
