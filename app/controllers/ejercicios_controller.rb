# Catálogo visual de ejercicios (SDD Fase 6): búsqueda para el editor, popup
# de ayuda con GIF + instrucciones, y media servida por proxy con caché en el
# volumen (la ruta del archivo sale SIEMPRE del registro, jamás de params).
class EjerciciosController < ApplicationController
  # Catálogo unificado (Fase 6.4 + 14.5): sin filtros muestra el explorador
  # por músculo (cards con portada y conteo); con q/musculo, el listado
  # buscable de siempre. La misma vista sirve la página completa del miembro
  # y el turbo-frame perezoso del modal del editor (máx. 30 resultados).
  def index
    authorize Ejercicio
    @ejercicios = Ejercicio.fuerza.ordenados.limit(30)
    if params[:q].present?
      @ejercicios = @ejercicios.where("nombre_normalizado LIKE :q OR LOWER(nombre_en) LIKE :q",
                                      q: "%#{Ejercicio.sanitize_sql_like(Ejercicio.normalizar(params[:q]))}%")
    end
    @ejercicios = @ejercicios.where(musculo: params[:musculo]) if params[:musculo].present?

    @explorar = params[:q].blank? && params[:musculo].blank?
    return unless @explorar

    # Dos queries para TODO el explorador: conteo por músculo + una portada
    # representativa por músculo (DISTINCT ON, primera alfabética con imagen).
    @conteos_musculo = Ejercicio.fuerza.group(:musculo).count
    @portadas_musculo = Ejercicio.fuerza.where.not(imagen_ruta: [ nil, "" ])
                                 .select("DISTINCT ON (musculo) id, musculo, imagen_ruta")
                                 .order(:musculo, :nombre)
                                 .index_by(&:musculo)
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
