class PartsController < ApplicationController
  def index
    @parts = Part.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @part = Part.find(params[:id])
  end

  def edit
    @part = Part.find(params[:id])
  end

  def update
    @part = Part.find(params[:id])
    if @part.update_attributes(params[:part])
      redirect_to part_path(params[:id]), :notice => "Information updated correctly."
    else
      render :edit
    end
  end

  def new
    @part = Part.new
    @organisms = Array.new
    @organisms << ['Saccharomyces cerevisiae', 1]
    @organisms << ['Escherichia coli', 2]
    @chromosomes = Chromosome.all
    @features = Feature.order('name').all
  end

  def confirm
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
    else
      redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file"
    end
  end

  def create
    if params[:accession].nil? && params[:sequence_file].nil?
      redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file"

    else
      @job = Job.create(job_type: JobType.find_by_name('part'), user: current_user, job_status: JobStatus.find_by_name('submitted'))

      if !params[:accession].nil?
        worker_params = {:job_id => @job.id, :accessions => params[:accession], :user_id => current_user.id, :seq_file => nil}
      else
        worker_params = {:job_id => @job.id, :accessions => nil, :user_id => current_user.id, :seq_file => params[:sequence_file]}
      end

      PartWorker.perform_async(worker_params)
      redirect_to job_path(@job.id), :notice => "Parts submitted!"
    end 
  end

  def get_description_file
    send_file "public/examples/description.txt", :type => "text", :disposition => 'inline'
  end

end
