class PartsController < ApplicationController
  def index
    @parts = current_user.lab.parts.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @part = Part.find(params[:id])
    @sequence = Bio::Sequence::NA.new(@part.sequence.seq)
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
    @features = Array.new
    @features << ['CDS', 5]
    @features << ['tRNA', 16]
    @features << ['repeat_region', 26]
    @features << ['rRNA', 32]
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

    elsif !params[:genome].blank?
      @parts = Annotation.search do |search|
        search.query do |query| 
          query.string params[:genome]
        end
        search.size 100
      end

    else
      redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file OR search genomes to create parts"
    end
  end

  def create
    if params[:accession].blank? && params[:sequence_file].blank? && params[:annotation_ids].blank?
      redirect_to new_part_path, :alert => "No input"

    else
      @job = Job.create(job_type: JobType.find_by_name('part'), user: current_user, job_status: JobStatus.find_by_name('submitted'))

      worker_params = {:job_id => @job.id, :accessions => params[:accession], :user_id => current_user.id, :seq_file => params[:sequence_file], :annotation_ids => params[:annotation_ids]}

      PartWorker.perform_async(worker_params)
      redirect_to job_path(@job.id), :notice => "Parts submitted!"
    end 
  end

  def get_description_file
    send_file "public/examples/description.txt", :type => "text", :disposition => 'inline'
  end

  def get_fasta_file
    send_file "public/parts/#{params[:id]}.fasta", :type => "chemical/seq-na-fasta FASTA", :disposition => 'attachment' 
  end

end
