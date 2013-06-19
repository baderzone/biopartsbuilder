class DesignsController < ApplicationController

  def index
    @designs = current_user.lab.designs.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @design = Design.find(params[:id])
  end

  def new
    @parts = Part.all
    @protocols = current_user.lab.protocols
    @design = Design.new
  end

  def create
    if params[:design].nil? || params[:design][:protocol_id].nil? || params[:design][:part_id].nil?
      redirect_to new_design_path, :alert => "At least one protocol and one part should be selected"
    
    else
      @job = Job.create(:job_type_id => JobType.find_by_name('design').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
      worker_params = {:job_id => @job.id, :protocol_id =>params[:design][:protocol_id], :part_id => params[:design][:part_id], :user_id => current_user.id}
      DesignWorker.perform_async(worker_params)
      redirect_to job_path(@job.id), :notice => "Designs submitted!"
    end
  end

  def fasta
    data = String.new
    design = Design.find(params[:id])
    design.constructs.each do |c|
      sequence = Bio::Sequence::NA.new(c.seq)
      data += sequence.to_fasta(c.name,80)
    end
    filename = "design_#{design.id}.fasta"
    send_data data, :filename => filename, :type => 'chemical/seq-na-fasta FASTA', :disposition => 'attachment'
  end

end
