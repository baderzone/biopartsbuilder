class JobsController < ApplicationController
  
  def index
    @jobs = current_user.job.order("created_at DESC")
  end
  
  def show
    @job = Job.find(params[:id])
  end

end
