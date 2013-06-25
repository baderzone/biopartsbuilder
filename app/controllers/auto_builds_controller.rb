class AutoBuildsController < ApplicationController

  def index
    redirect_to orders_path
  end

  def new
    @protocols = current_user.lab.protocols
  end

  def confirm
    if params[:order_name].blank? || (params[:accession].blank? && params[:sequence_file].blank? && params[:genome].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers or search genomes"
    else

      @errors = Array.new
      if !params[:accession].blank?
        @accessions = params[:accession].strip.split("\r\n")
        @accessions.delete('')

      elsif !params[:sequence_file].blank?
        # upload file
        uploader = SequenceFileUploader.new
        uploader.store!(params[:sequence_file])
        @seq_file = uploader.current_path

        # check file
        @sequences, @errors = FastaFile.check(@seq_file)

      elsif !params[:genome].blank?
        @parts = Annotation.search do |search|
          search.query do |query| 
            query.string params[:genome]
          end
          search.size 100
        end
      end

      @protocol = Protocol.find(params[:protocol_id])
      @vendor = params[:order][:vendor_id]
      @order = params[:order_name]
    end
  end

  def create
    if params[:order_name].blank? || (params[:accession].blank? && params[:sequence_file].blank? && params[:annotation_ids].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers or search genomes"
    else

      @order = Order.new(:name => params[:order_name], :user_id => current_user.id, :vendor_id => params[:vendor_id])
      if @order.save
        @job = Job.create(:job_type_id => JobType.find_by_name('auto_build').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)

        worker_params = {:job_id => @job.id, :accessions => params[:accession], :seq_file => params[:sequence_file], :annotation_ids => params[:annotation_ids], :order_id => @order.id, :protocol_id => params[:protocol_id]}

        AutoBuild.perform_async(worker_params)
        redirect_to job_path(@job.id), :notice => "AutoBuild submitted!"
      else
        render :new, :flash => {:error => "AutoBuild failed. Please try again or contact administrator!" }
      end
    end
  end

end
