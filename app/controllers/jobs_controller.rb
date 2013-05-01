class JobsController < ApplicationController
  
  def index
    @jobs = current_user.job.paginate(:page => params[:page], :per_page => 10).order("id DESC")
  end
  
  def show
    @job = Job.find(params[:id])
  end

end
