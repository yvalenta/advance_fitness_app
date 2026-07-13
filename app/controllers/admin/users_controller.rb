class Admin::UsersController < ApplicationController
  def index
    authorize User
    @q = params[:q].to_s.strip
    @users = policy_scope(User).includes(:membresia).order(:nombre)
    @users = @users.where("nombre ILIKE :q OR email_address ILIKE :q", q: "%#{User.sanitize_sql_like(@q)}%") if @q.present?
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @accesos = @user.accesos.recientes.limit(10)
    @plan = @user.plan_actual
  end
end
