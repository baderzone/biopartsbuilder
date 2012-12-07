class DesignsController < ApplicationController

  def index
    @designs = Design.all
  end

  def show
    @design = Design.find(params[:id])
  end

  def new
    @parts = Part.all
    @protocols = Protocol.all
    @design = Design.new
  end

  def create
    if params[:design].nil? || params[:design][:protocol_id].nil? || params[:design][:part_id].nil?
      redirect_to new_design_path, :alert => "At least one protocol and one part should be selected"
    else
      @job = Job.create(:job_type_id => JobType.find_by_name('design').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
      worker_params = {:job_id => @job.id, :protocol_id =>params[:design][:protocol_id], :part_id => params[:design][:part_id], :user_id => current_user.id}
      Resque.enqueue(DesignPart, worker_params)
      redirect_to job_path(@job.id), :notice => "Designs submitted!"
    end
  end

end
