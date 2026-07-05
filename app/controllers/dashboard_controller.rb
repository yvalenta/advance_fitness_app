class DashboardController < ApplicationController
  def show
    @membresia = Current.user.membresia
  end
end
