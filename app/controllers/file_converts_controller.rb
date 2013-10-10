class FileConvertsController < ApplicationController

  def index
    @files = current_user.file_converts.paginate(:page => params[:page], :per_page => 10).order("id DESC")
  end

  def new
    @file = FileConvert.new
  end

  def create
    if params[:file].blank?
      redirect_to new_file_convert_path, :flash => {:error => "Please upload a file!"}
    elsif params[:map_id] == 'yes' and params[:first_id].blank?
      redirect_to new_file_convert_path, :flash => {:error => "Must provide the first number!"}
    else

      uploader = FileUploader.new
      uploader.store!(params[:file])
      @file = FileConvert.new(:name => params[:name])
      @file.user_id = current_user.id
      
      if @file.save
        @job = Job.create(:job_type_id => JobType.find_by_name('file_convert').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
        worker_params = {:input => {'type' => 'fasta', 'file' => uploader.current_path}, :output_types => params[:output_types], :map_id => params[:map_id], :first_id => params[:first_id], :job_id => @job.id, :converter_id => @file.id}
        ConverterWorker.perform_async(worker_params)
        redirect_to job_path(@job.id), :notice => "File submitted!"
      else
        flash[:error] = 'Something went wrong. Please try again!'
        render :new
      end 
    end
  end 

  def get_zip_file
    result_path = "#{PARTSBUILDER_CONFIG['program']['converter_path']}/#{params[:id]}"
    filename = "#{result_path}/parts.zip"
    send_file filename, :type => 'archive/zip', :disposition => 'inline'
  end

end
