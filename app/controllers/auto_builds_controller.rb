class AutoBuildsController < ApplicationController

  def index
    redirect_to orders_path
  end

  def new
    @protocols = Protocol.all
  end

  def confirm
    if params[:order_name].empty? || (params[:accession].empty? && params[:sequence_file].nil?) || params[:protocol_id].nil? 
      redirect_to new_auto_build_path, :alert => "Order name and accession number cannot be empty. And please select one protocol"
    else
      
      @errors = Hash.new
      if params[:sequence_file].nil?
        @accessions = params[:accession].strip.split("\r\n")
        @accession_origin = params[:accession]
      else
        uploader = SequenceFileUploader.new
        uploader.store!(params[:sequence_file])
        @seq_file = uploader.current_path
        @sequences = Hash.new
       
        cnt = 0
        in_file = Bio::FastaFormat.open(@seq_file, 'r')
        in_file.each do |entry|
          cnt += 1
          seq_descript_array = entry.definition.split('|')
          if seq_descript_array.length >= 2
            @sequences[cnt] = {'part' => seq_descript_array[0].strip, 'accession' => seq_descript_array[1].strip, 'org' => seq_descript_array[2]||'unknown'}
          else
            @errors[cnt] = {'error' => "Format invalid: #{entry.definition}"}
          end
        end
        in_file.close

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
          accession = params[:accession].strip.split("\r\n")
          worker_params = {:job_id => @job.id, :accession => accession, :order_id => @order.id, :protocol_id => params[:protocol_id]}
        else
          worker_params = {:job_id => @job.id, :accession => "none", :seq_file => params[:sequence_file], :order_id => @order.id, :protocol_id => params[:protocol_id]}
        end
        
        Resque.enqueue(AutoBuild, worker_params)
        redirect_to job_path(@job.id), :notice => "AutoBuild submitted!"
      else
        render :new, :flash => {:error => "AutoBuild failed. Please try again or contact administrator!" }
      end
    end
  end

end
