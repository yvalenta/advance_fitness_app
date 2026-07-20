class Admin::UsersController < ApplicationController
  def index
    authorize User
    @q = params[:q].to_s.strip
    @users = policy_scope(User).includes(:membresia).order(:nombre)
    @users = @users.where("nombre ILIKE :q OR email_address ILIKE :q", q: "%#{User.sanitize_sql_like(@q)}%") if @q.present?
    @users = @users.page(params[:page]).per(25)
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @accesos = @user.accesos.recientes.limit(10)
    @plan = @user.plan_actual
    @progreso = ProgresoUsuario.para(@user)
    @registro_reciente = @user.registros_entrenamiento.order(fecha: :desc).first
  end

  # Dashboard del miembro (Fase 6.13): datos básicos editables por staff.
  # El rol y el VIP NUNCA se mass-asignan (regla del proyecto) — se aplican
  # aparte y solo si quien edita es admin (un entrenador no puede ascender a
  # nadie ni otorgar acceso VIP sin vencimiento, Fase 12.2).
  def update
    @user = User.find(params[:id])
    authorize @user
    @user.rol = params[:user][:rol] if Current.user.admin? && params[:user][:rol].present?
    @user.vip = ActiveModel::Type::Boolean.new.cast(params[:user][:vip]) if Current.user.admin? && params[:user].key?(:vip)

    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "Perfil actualizado."
    else
      @accesos = @user.accesos.recientes.limit(10)
      @plan = @user.plan_actual
      @progreso = ProgresoUsuario.para(@user)
      @registro_reciente = @user.registros_entrenamiento.order(fecha: :desc).first
      render :show, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: %i[nombre email_address fecha_nacimiento sexo nivel_actividad somatotipo])
    end
end
