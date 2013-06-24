class OrderWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(params)
    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    
    # create order files
    vendor = Vendor.find(params['vendor_id'])
    design_ids = params['designs']
    order = Order.find(params['order_id'])
    path = "#{PARTSBUILDER_CONFIG['program']['order_path']}"
    file = BioOrder.new.store(path, order.id, design_ids, vendor.name)
    
    # change job status and send email notice
    job.change_status('finished')
    PartsbuilderMailer.finished_notice(order.user, nil).deliver
  end

end
