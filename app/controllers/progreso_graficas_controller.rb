# Sirve UNA gráfica de /progreso dentro de su turbo-frame perezoso
# (Fase 16.6, patrón gestion_semanas): el frame con loading: :lazy la pide
# al entrar al viewport y este controller carga SOLO su sección de datos.
class ProgresoGraficasController < ApplicationController
  PERIODOS_MAPA_MUSCULAR = %w[semana mes todo].freeze

  def show
    authorize :progreso, :show?
    @tipo = params[:tipo] # la ruta ya lo restringe (ver routes.rb)
    @periodo = PERIODOS_MAPA_MUSCULAR.include?(params[:periodo]) ? params[:periodo].to_sym : :semana
    @progreso = ProgresoUsuario.seccion(Current.user, @tipo, periodo: @periodo)
    render layout: false
  end
end
