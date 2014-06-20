require 'xmlsimple' 
require 'csv'

class AutoBuild
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(params)

    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    error_info = String.new
    order = Order.find(params['order_id'])

    # retrieve parts
    biopart = BioPart.new
    if !params['seq_file'].blank?
      data, error_info = biopart.retrieve(params['seq_file'], 'fasta', order.user.id)
    elsif !params['accessions'].blank?
      data, error_info = biopart.retrieve(params['accessions'], 'ncbi', order.user.id)
    else
      data, error_info = biopart.retrieve(params['annotation_ids'], 'genome', order.user.id)
    end 
    # store parts
    part_ids = biopart.store(data, order.user.id) if error_info.empty? 

    # design part 
    if error_info.empty?
      protocol = Protocol.find(params['protocol_id'])
      processing_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
      biodesign = BioDesign.new
      data, error_info = biodesign.create_designs(part_ids, processing_path, protocol, 'new')
    end
    # store designs
    design_ids = biodesign.store(data, protocol, order.user.id, 'new') if error_info.empty?    

    # create order files
    if error_info.empty? 
      order = Order.find(params['order_id'])
      order.design_ids = design_ids
      order.save
      path = "#{PARTSBUILDER_CONFIG['program']['order_path']}"
      file = BioOrder.new.store(path, order.id, design_ids, order.vendor.name)
    end

    # change job status
    if error_info.empty?
      job.change_status('finished')
    else
      job.change_status('failed')
      job.error_info = error_info
      job.save
    end
    # send email notice
    PartsbuilderMailer.finished_notice(order.user, error_info).deliver

  end 

end
