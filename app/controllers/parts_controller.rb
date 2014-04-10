class PartsController < ApplicationController
  def index
    @parts = current_user.lab.parts.paginate(:page => params[:page], :per_page => 10).order('id DESC')
  end

  def show
    @part = Part.find(params[:id])
    @p_seq = @part.protein_seq
    @d_seq = @part.dna_seq
    @protein_seq = Bio::Sequence::NA.new(@p_seq.seq) unless @p_seq.nil?
    @dna_seq  = Bio::Sequence::NA.new(@d_seq.seq) unless @d_seq.nil?
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

    if !params[:accession].blank?
      @accessions = params[:accession].strip.split("\r\n")
      @accessions.delete('')

    elsif !params[:sequence_file].blank?
      # upload file
      uploader = SequenceFileUploader.new
      begin
        uploader.store!(params[:sequence_file])
      rescue
        return redirect_to new_part_path, :alert => "Upload Failed! Only .fa, .fasta and .txt allowed"
      end
      @seq_file = uploader.current_path

      # check file
      @sequences, @errors = FastaFile.check(@seq_file)

    elsif !params[:genome].blank?
      begin
        @parts = Annotation.search do |search|
          search.query do |query| 
            query.string params[:genome]
          end
          search.size 100
        end
      rescue
        return redirect_to new_part_path, :alert => "Your query '#{params[:genome]}' format is not correct, please check"
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
    sequence = Sequence.find(params[:id])
    data = Bio::Sequence::NA.new(sequence.seq)
    seqid = sequence.part.name
    filename = "#{seqid}.fasta"
    send_data data.to_fasta(seqid,80), :filename => filename, :type => 'chemical/seq-na-fasta FASTA', :disposition => 'attachment'
  end

end
