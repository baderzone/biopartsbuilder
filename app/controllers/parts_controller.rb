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

	def confirm
		if params[:accession].empty? && params[:sequence_file].nil?
			redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file"
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
            @errors[cnt] = {'error' => "The format is not correct for #{entry.definition}"}
          end
        end
        in_file.close
			end
		end 
	end

	def create
		if params[:accession].nil? && params[:sequence_file].nil?
			redirect_to new_part_path, :alert => "Please input a list of accession numbers OR upload a FASTA file"
		else
			@job = Job.create(:job_type_id => JobType.find_by_name('part').id, :user_id => current_user.id, :job_status_id => JobStatus.find_by_name('submitted').id)
			if params[:sequence_file].nil?
				accession = params[:accession].strip.split("\r\n")
				worker_params = {:job_id => @job.id, :accession => accession, :user_id => current_user.id}
			else
				worker_params = {:job_id => @job.id, :accession => "none", :user_id => current_user.id, :seq_file => params[:sequence_file]}
			end
			Resque.enqueue(NewPart, worker_params)
			redirect_to job_path(@job.id), :notice => "Parts submitted!"
		end 
	end

	def get_description_file
		send_file "public/examples/#{params[:name]}", :type => "#{params[:type]}", :disposition => 'inline'
	end

end
