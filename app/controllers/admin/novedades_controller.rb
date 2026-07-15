class Admin::NovedadesController < ApplicationController
  before_action :cargar_novedad, only: %i[ edit update destroy ]

  def index
    authorize Novedad, :admin_index?
    @novedades = Novedad.order(fecha_evento: :desc, created_at: :desc)
  end

  def new
    @novedad = Novedad.new
    authorize @novedad
  end

  def create
    @novedad = Novedad.new(novedad_params)
    authorize @novedad

    if @novedad.save
      redirect_to admin_novedades_path, notice: "Novedad creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @novedad.update(novedad_params)
      redirect_to admin_novedades_path, notice: "Novedad actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @novedad.destroy
    redirect_to admin_novedades_path, notice: "Novedad eliminada."
  end

  private
    def cargar_novedad
      @novedad = Novedad.find(params[:id])
      authorize @novedad
    end

    def novedad_params
      params.expect(novedad: [ :titulo, :contenido, :fecha_evento, :publicado ])
    end
end
