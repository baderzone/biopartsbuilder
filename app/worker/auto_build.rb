require 'xmlsimple' 
require 'csv'

class AutoBuild
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

    # design part 
    if error_info.empty?
      protocol = Protocol.find(params['protocol_id'])
      processing_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
      biodesign = BioDesign.new
      data, error_info = biodesign.create_designs(part_ids, processing_path, protocol, 'new')
    end
    # store designs
    design_ids = biodesign.store(data, protocol, 'new') if error_info.empty?    

    # create order files
    if error_info.empty? 
      order = Order.find(params['order_id'])
      path = "#{PARTSBUILDER_CONFIG['program']['order_path']}"
      file = BioOrder.store(path, order.id, design_ids)
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
    order = Order.find(params['order_id'])
    PartsbuilderMailer.finished_notice(order.user, error_info).deliver

  end 

end
