class Admin::MembresiasController < ApplicationController
  def index
    authorize Membresia
    @membresias = policy_scope(Membresia).includes(:user).order(:fecha_vencimiento)
  end

  def new
    @membresia = Membresia.new(fecha_inicio: Date.current)
    authorize @membresia
  end

  # Alta = membresía + primer pago, en una sola transacción
  def create
    @membresia = Membresia.new(membresia_params)
    @membresia.fecha_vencimiento = @membresia.fecha_inicio + Membresia.duracion if @membresia.fecha_inicio
    authorize @membresia

    Membresia.transaction do
      @membresia.save!
      @membresia.pagos.create!(
        monto: params[:membresia][:monto],
        metodo: params[:membresia][:metodo],
        registrado_por: Current.user,
        fecha_pago: Date.current,
        periodo_inicio: @membresia.fecha_inicio,
        periodo_fin: @membresia.fecha_vencimiento
      )
    end
    # Plan sugerido incluido (Fase 5.11); si el miembro aún no tiene objetivo,
    # Mi plan se lo pregunta y el plan nace al fijarlo.
    PlanPersonalizado.asegurar_sugerido!(@membresia.user)
    redirect_to admin_membresias_path, notice: "Membresía creada para #{@membresia.user.nombre}."
  rescue ActiveRecord::RecordInvalid => error
    @membresia.errors.add(:base, error.message) if @membresia.errors.empty?
    render :new, status: :unprocessable_entity
  end

  def edit
    @membresia = Membresia.find(params[:id])
    authorize @membresia
  end

  def update
    @membresia = Membresia.find(params[:id])
    authorize @membresia
    @membresia.assign_attributes(membresia_params.except(:user_id))

    if @membresia.save
      redirect_to admin_membresias_path, notice: "Membresía actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def membresia_params
      params.expect(membresia: [ :user_id, :fecha_inicio, :estado ])
    end
end
