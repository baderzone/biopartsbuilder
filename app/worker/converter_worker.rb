class ConverterWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(params)
    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    
    # create order files
    converter = FileConvert.find(params['converter_id'])
    FileConverter.new.convert(params['input'], converter.id, params['output_types'])
    
    # change job status and send email notice
    job.change_status('finished')
    PartsbuilderMailer.finished_notice(converter.user, nil).deliver
  end

end
