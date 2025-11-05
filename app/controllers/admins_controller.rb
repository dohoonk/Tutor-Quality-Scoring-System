class AdminsController < ApplicationController
  def show
    @admin_id = params[:id]
  end
end
