class UpdateDesign
  include Sidekiq::Worker

  def perform(params)

    error_info = String.new
    # design part 
    part_ids = params['part_id']
    protocol = Protocol.find(params['protocol_id'])
    processing_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
    biodesign = BioDesign.new
    data, error_info = biodesign.create_designs(part_ids, processing_path, protocol, 'update')
    # store data
    design_ids = biodesign.store(data, protocol, 'update') if error_info.empty?

  end

end
