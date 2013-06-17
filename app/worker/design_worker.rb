class DesignWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(params)

    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    error_info = String.new

    # design part 
    part_ids = params['part_id']
    protocol = Protocol.find(params['protocol_id'])
    processing_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
    biodesign = BioDesign.new
    data, error_info = biodesign.create_designs(part_ids, processing_path, protocol, 'new')
    # store data
    design_ids = biodesign.store(data, protocol, 'new') if error_info.empty?

    # change job status
    if error_info.empty?
      job.change_status('finished')
    else
      job.change_status('failed')
      job.error_info = error_info
      job.save
    end
    # send email notice
    current_user = User.find(params['user_id'])
    PartsbuilderMailer.finished_notice(current_user, error_info).deliver

  end

end
