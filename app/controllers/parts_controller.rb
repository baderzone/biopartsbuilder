class PartsController < ApplicationController
  def index
    @parts = Part.all
  end

  def show
    @part = Part.find(params[:id])
  end

  def new
    @part = Part.new
  end

  def create
    if params[:accession].empty?
      redirect_to new_part_path, :alert => "Accession number can't be empty"
    else
      @job = Job.create(:job_type_id => get_job_type_id('part'), :user_id => current_user.id, :job_status_id => get_job_status_id('submitted'))
      params[:accession].strip.split("\r\n").each do |entry|
        entry.strip!
        if Sequence.where("accession = ?", entry).empty?
         # Resque.enqueue(NewPart, entry)
        end 
      end 
      redirect_to job_path(@job.id), :notice => "Parts submitted correctly!"
    end 
  end

end
