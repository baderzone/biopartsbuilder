class AutoBuildsController < ApplicationController

  def index
    redirect_to orders_path
  end

  def new
    @protocols = current_user.lab.protocols
    @organisms = Array.new
    @organisms << ['Saccharomyces cerevisiae', 1]
    @organisms << ['Escherichia coli', 2]
    @chromosomes = Chromosome.all
    @features = Array.new
    @features << ['CDS', 5]
    @features << ['tRNA', 16]
    @features << ['repeat_region', 26]
    @features << ['rRNA', 32]
  end

  def confirm
    if params[:order_name].blank? || (params[:accession].blank? && params[:sequence_file].blank? && params[:start].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers"
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

      elsif !params[:start].blank? && !params[:end].blank?
        if params[:end].to_i == 0
          @errors << "Start and end position must be integer"
        else
          @organism = Organism.find(params[:organism])
          @chromosome = Chromosome.find(params[:chromosome])
          @feature = Feature.find(params[:feature])
          @strand = params[:strand]
          @start = params[:start].to_i
          @end = params[:end].to_i
          if params[:strand] == '+/-'
            @parts = Annotation.where("chromosome_id = ? AND feature_id = ? AND start >= ? AND end <= ?", @chromosome.id, @feature.id, @start, @end) 
          else
            @parts = Annotation.where("chromosome_id = ? AND feature_id = ? AND strand = ? AND start >= ? AND end <= ?", @chromosome.id, @feature.id, params[:strand], @start, @end) 
          end
        end
      end

      @protocol = Protocol.find(params[:protocol_id])
      @vendor = params[:order][:vendor_id]
      @order = params[:order_name]
    end
  end

  def create
    if params[:order_name].blank? || (params[:accession].blank? && params[:sequence_file].blank? && params[:annotation_ids].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a fasta file or input accession numbers"
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
