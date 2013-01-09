class PartsController < ApplicationController
	def index
		@parts = Part.all
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

	def create
		if params[:accession].empty? && params[:sequence_file].nil?
			redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file"
		else
			@job = Job.create(:job_type_id => JobType.find_by_name('part').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
			if params[:sequence_file].nil?
				accession = params[:accession].strip.split("\r\n")
				worker_params = {:job_id => @job.id, :accession => accession, :user_id => current_user.id}
			else
				uploader = SequenceFileUploader.new
				uploader.store!(params[:sequence_file])
				worker_params = {:job_id => @job.id, :accession => "none", :user_id => current_user.id, :seq_file => uploader.current_path}
			end
			Resque.enqueue(NewPart, worker_params)
			redirect_to job_path(@job.id), :notice => "Parts submitted!"
		end 
	end

	def get_description_file
		send_file "public/examples/#{params[:name]}", :type => "#{params[:type]}", :disposition => 'inline'
	end

end
