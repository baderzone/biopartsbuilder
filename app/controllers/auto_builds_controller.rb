class AutoBuildsController < ApplicationController

  def index
    redirect_to orders_path
  end

  def new
    @protocols = current_user.lab.protocols
  end

  def confirm
    @existing_parts = []
    if params[:order_name].blank? || (params[:accession].blank?  && params[:csv_file].blank? && params[:sequence_file].blank? && params[:genome].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a cav/fasta file or input accession numbers or search genomes"
    else

      @errors = Array.new
      if !params[:accession].blank?
        @accessions = params[:accession].strip.split("\r\n")
        @accessions.delete('')
        @accessions.each do |a|
          if !Sequence.find_by_accession_and_lab_id(a, current_user.lab_id).blank?
            @existing_parts << a
          end
        end

      elsif !params[:csv_file].blank?
        # upload file
        uploader = CsvFileUploader.new
        uploader.store!(params[:csv_file])
        @csv_file = uploader.current_path

        # check file
        @csv_seqs, @errors = CsvFile.check(@csv_file)
        @csv_seqs.each do |s|
          if !Sequence.find_by_accession_and_lab_id(s['accession'], current_user.lab_id).blank?
            @existing_parts << s['accession']
          end
        end


      elsif !params[:sequence_file].blank?
        # upload file
        uploader = SequenceFileUploader.new
        begin 
          uploader.store!(params[:sequence_file])
        rescue
          return redirect_to new_auto_build_path, :alert => "Upload Failed! Only .fa, .fasta and .txt allowed"
        end
        @seq_file = uploader.current_path

        # check file
        @sequences, @errors = FastaFile.check(@seq_file)
        @sequences.each do |s|
          if !Sequence.find_by_accession_and_lab_id(s['accession'], current_user.lab_id).blank?
            @existing_parts << s['accession']
          end
        end


      elsif !params[:genome].blank?
        begin
          @parts = Annotation.search do |search|
            search.query do |query| 
              query.string params[:genome]
            end
            search.size 100
          end
          @parts.each do |p|
            if !Sequence.find_by_accession_and_lab_id(p.systematic_name, current_user.lab_id).blank?
              @existing_parts << p.systematic_name
            end 
          end
        rescue
          return redirect_to new_auto_build_path, :alert => "Your query '#{params[:genome]}' format is not correct, please check"
        end
      end

      @protocol = Protocol.find(params[:protocol_id])
      @vendor = params[:order][:vendor_id]
      @order = params[:order_name]
    end
  end

  def create
    if params[:order_name].blank? || (params[:accession].blank? && params[:csv_file].blank? && params[:sequence_file].blank? && params[:annotation_ids].blank?) || params[:protocol_id].blank? 
      redirect_to new_auto_build_path, :alert => "Something is missing. Make sure to select one design standard, input order name, upload a csv/fasta file or input accession numbers or search genomes"
    else

      @order = Order.new(:name => params[:order_name], :user_id => current_user.id, :vendor_id => params[:vendor_id])
      if @order.save
        @job = Job.create(:job_type_id => JobType.find_by_name('auto_build').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)

        worker_params = {:job_id => @job.id, :accessions => params[:accession], :csv_file => params[:csv_file], :seq_file => params[:sequence_file], :annotation_ids => params[:annotation_ids], :order_id => @order.id, :protocol_id => params[:protocol_id]}

        AutoBuild.perform_async(worker_params)
        redirect_to job_path(@job.id), :notice => "AutoBuild submitted!"
      else
        render :new, :flash => {:error => "AutoBuild failed. Please try again or contact administrator!" }
      end
    end
  end

end
