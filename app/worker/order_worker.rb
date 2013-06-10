class OrderWorker
  include Sidekiq::Worker

  def perform(params)
    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    design_ids = params['designs']
    # create order files
    order = Order.find(params['order_id'])
    path = "#{PARTSBUILDER_CONFIG['program']['order_path']}"
    file = BioOrder.new(path, order.id, design_ids).to_s
    # change job status and send email notice
    job.change_status('finished')
    PartsbuilderMailer.finished_notice(order.user, nil).deliver
  end

end
