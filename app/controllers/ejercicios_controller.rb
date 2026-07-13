# Catálogo visual de ejercicios (SDD Fase 6): búsqueda para el editor, popup
# de ayuda con GIF + instrucciones, y media servida por proxy con caché en el
# volumen (la ruta del archivo sale SIEMPRE del registro, jamás de params).
class EjerciciosController < ApplicationController
  # Búsqueda del catálogo para el modal del editor (turbo-frame, máx. 30)
  def index
    authorize Ejercicio
    @ejercicios = Ejercicio.fuerza.ordenados.limit(30)
    if params[:q].present?
      @ejercicios = @ejercicios.where("nombre_normalizado LIKE :q OR LOWER(nombre_en) LIKE :q",
                                      q: "%#{Ejercicio.sanitize_sql_like(Ejercicio.normalizar(params[:q]))}%")
    end
    @ejercicios = @ejercicios.where(musculo: params[:musculo]) if params[:musculo].present?
  end

  # Popup de ayuda: por id (rutinas nuevas), por nombre contra el catálogo, o
  # vía la plantilla enlazada (cubre rutinas viejas generadas desde la
  # biblioteca en español, sin ejercicio_id en su JSON).
  # `marco` (whitelist) permite dos dialogs en la misma página (rutina/editor).
  def ayuda
    authorize Ejercicio
    @ejercicio = Ejercicio.find_by(id: params[:ejercicio_id]) ||
                 Ejercicio.buscar_por_nombre(params[:nombre]) ||
                 PlantillaEjercicio.find_by(nombre: params[:nombre].to_s.strip)&.ejercicio
    @nombre_consultado = params[:nombre]
    @marco = params[:marco].presence_in(%w[ayuda_ejercicio ayuda_ejercicio_editor]) || "ayuda_ejercicio"
  end

  # GET /ejercicios/:id/media/:tipo (gif|imagen) — descarga on-demand + caché
  def media
    ejercicio = Ejercicio.find(params[:id])
    authorize ejercicio

    ruta_relativa = params[:tipo] == "gif" ? ejercicio.gif_ruta : ejercicio.imagen_ruta
    return head :not_found if ruta_relativa.blank?

    archivo = Ejercicios::MediaCache.asegurar!(ruta_relativa)
    expires_in 1.year, public: true
    send_file archivo, type: params[:tipo] == "gif" ? "image/gif" : "image/jpeg", disposition: "inline"
  rescue Ejercicios::MediaCache::MediaNoDisponible
    head :not_found
  end
end
