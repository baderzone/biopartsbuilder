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
  end

  def confirm
    @errors = Array.new

    if !params[:accession].empty?
      @accessions = params[:accession].strip.split("\r\n")
      @accessions.delete('')

    elsif !params[:sequence_file].nil?
      # upload file
      uploader = SequenceFileUploader.new
      uploader.store!(params[:sequence_file])
      @seq_file = uploader.current_path

      # check file
      @sequences, @errors = FastaFile.check(@seq_file)
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
