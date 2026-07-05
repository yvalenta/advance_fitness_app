class Admin::UsersController < ApplicationController
  def index
    authorize User
    @users = policy_scope(User).includes(:membresia).order(:nombre)
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @accesos = @user.accesos.recientes.limit(10)
  end
end
