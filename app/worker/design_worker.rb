class DesignWorker
  @queue = :partsbuilder_new_design_queue

  def self.perform(para)

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    error_info = Array.new
    is_new_design_success = true
    part_ids = para['part_id']

    # design part 
    protocol = Protocol.find(para['protocol_id'])
    processing_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
    construct_suf = '_CO'
    case protocol.organism_id
    when 1
      construct_suf += 'y'
    when 2
      construct_suf += 'e'
    when 3
      construct_suf += 'h'
    when 4
      construct_suf += 'w'
    when 5
      construct_suf += 'f'
    when 6
      construct_suf += 'b'
    else
      construct_suf = ''
    end

    designs = Array.new
    part_ids.each do |part_id|
      if Design.find_by_part_id_and_protocol_id(part_id, protocol.id).nil?
        part = Part.find(part_id)
        protein_file = "#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{part.sequence.accession}.fasta"
        biodesign = BioDesign.new(protein_file, processing_path, protocol).to_s
        if biodesign[:error].nil?
          biodesign[:part_id] = part.id
          biodesign[:part_name] = part.name
          designs << biodesign
        else
          is_new_design_success = false
          error_info << "#{part.name}: #{biodesign[:error]}"
          break
        end
      end
    end

    # store data
    designs.each do |entry|
      design = Design.create(:part_id => entry[:part_id], :protocol_id => protocol.id, :comment => entry[:comment])
      entry[:construct].each do |i, seq|
        construct_name = entry[:part_name] + construct_suf + "_#{i}" 
        design.constructs.create(:name => construct_name, :seq => seq)
      end
    end if is_new_design_success

    # change job status
    if is_new_design_success
      job.change_status('finished')
    else
      job.change_status('failed')
      job.error_info = error_info.join(' ')
      job.save
    end
    # send email notice
    current_user = User.find(para['user_id'])
    PartsbuilderMailer.finished_notice(current_user, error_info).deliver

  end

end
