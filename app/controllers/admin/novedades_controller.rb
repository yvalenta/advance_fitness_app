class Admin::NovedadesController < ApplicationController
  before_action :cargar_novedad, only: %i[ edit update destroy ]

  def index
    authorize Novedad, :admin_index?
    # policy_scope: el staff solo administra las novedades de SU tenant (Fase 18f).
    @novedades = policy_scope(Novedad).order(fecha_evento: :desc, created_at: :desc)
  end

  def new
    @novedad = Novedad.new
    authorize @novedad
  end

  def create
    # tenant explícito del staff que crea: sin él la novedad nacía global
    # (tenant_id nil) y se filtraba a los demás tenants (Fase 18f).
    @novedad = Novedad.new(novedad_params.merge(tenant_id: Current.user.tenant_id))
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
      # Buscar dentro del scope: editar por id una novedad de otro tenant es
      # 404, no un authorize que dependa de que la policy mire el tenant.
      @novedad = policy_scope(Novedad).find(params[:id])
      authorize @novedad
    end

    def novedad_params
      params.expect(novedad: [ :titulo, :contenido, :fecha_evento, :publicado ])
    end
end
