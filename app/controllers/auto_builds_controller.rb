class AutoBuildsController < ApplicationController

  def index
    redirect_to orders_path
  end

  def new
    @protocols = Protocol.all
  end

  def confirm
    if params[:order_name].empty? || (params[:accession].empty? && params[:sequence_file].nil?) || params[:protocol_id].nil? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers"
    else

      @errors = Array.new
      if !params[:accession].empty?
        @accessions = params[:accession].strip.split("\r\n")
        @accessions.delete('')

      else
        # upload file
        uploader = SequenceFileUploader.new
        uploader.store!(params[:sequence_file])
        @seq_file = uploader.current_path

        # check file
        @sequences, @errors = FastaFile.check(@seq_file)
      end

      @protocol = Protocol.find(params[:protocol_id])
      @vendor = params[:order][:vendor_id]
      @order = params[:order_name]
    end
  end

  def create
    if params[:order_name].empty? || (params[:accession].nil? && params[:sequence_file].nil?) || params[:protocol_id].nil? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers"
    else

      @order = Order.new(:name => params[:order_name], :user_id => current_user.id, :vendor_id => params[:vendor_id])
      if @order.save

        @job = Job.create(:job_type_id => JobType.find_by_name('auto_build').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)

        if params[:sequence_file].nil?
          worker_params = {:job_id => @job.id, :accessions => params[:accession], :order_id => @order.id, :protocol_id => params[:protocol_id]}
        else
          worker_params = {:job_id => @job.id, :accessions => "none", :seq_file => params[:sequence_file], :order_id => @order.id, :protocol_id => params[:protocol_id]}
        end

        AutoBuild.perform_async(worker_params)
        redirect_to job_path(@job.id), :notice => "AutoBuild submitted!"
      else
        render :new, :flash => {:error => "AutoBuild failed. Please try again or contact administrator!" }
      end
    end
  end

end
