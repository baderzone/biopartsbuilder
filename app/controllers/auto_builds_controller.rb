class AutoBuildsController < ApplicationController

  def new
    @protocols = Protocol.all
  end

  def create
    if params[:order_name].empty? || params[:accession].empty? || params[:protocol_id].nil?
      redirect_to new_auto_build_path, :alert => "Order name and accession number cannot be empty. And please select one protocol"
    else
      @job = Job.create(:job_type_id => JobType.find_by_name('auto_build').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
      accession = params[:accession].strip.split("\r\n")
      worker_params = {:job_id => @job.id, :accession => accession, :order_name => params[:order_name], :vendor_id => params[:order][:vendor_id], :protocol_id => params[:protocol_id]}
      Resque.enqueue(AutoBuild, worker_params)
      redirect_to job_path(@job.id), :notice => "AutoBuild submitted!"
    end
  end
end
