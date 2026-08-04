# Sirve UNA gráfica de /progreso dentro de su turbo-frame perezoso
# (Fase 16.6, patrón gestion_semanas): el frame con loading: :lazy la pide
# al entrar al viewport y este controller carga SOLO su sección de datos.
class ProgresoGraficasController < ApplicationController
  def show
    authorize :progreso, :show?
    @tipo = params[:tipo] # la ruta ya lo restringe a peso|calorias|asistencia
    @progreso = ProgresoUsuario.seccion(Current.user, @tipo)
    render layout: false
  end
end
