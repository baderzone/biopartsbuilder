require 'csv'

class PartWorker
  include Sidekiq::Worker

  def perform(params)

    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    error_info = String.new

    # retrieve parts
    biopart = BioPart.new
    if !params['seq_file'].nil?
      data, error_info = biopart.retrieve(params['seq_file'], 'fasta')
    else
      data, error_info = biopart.retrieve(params['accessions'], 'ncbi')
    end
    # check parts
    error_info = biopart.check(data) if error_info.empty? 
    # store parts
    part_ids = biopart.store(data) if error_info.empty?

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
