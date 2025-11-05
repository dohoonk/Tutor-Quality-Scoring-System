class TutorsController < ApplicationController
  def show
    @tutor_id = params[:id]
  end
end
