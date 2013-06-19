class BioDesign

  def create_designs(part_ids, processing_path, protocol, type)
    designs = Array.new
    error = String.new

    part_ids.each do |part_id|
      design = Design.find_by_part_id_and_protocol_id(part_id, protocol.id)

      if design.nil? || type.eql?('update')
        # creat new design
        part = Part.find(part_id)
        biodesign = golden_gate(part.id, processing_path, protocol, part.sequence.organism_id)
        if biodesign[:error].nil?
          biodesign[:part_id] = part.id
          biodesign[:part_name] = part.name
          designs << biodesign
        else
          error = "#{part.name}: #{biodesign[:error]}"
          return designs, error
        end

      else
        # retrieve exist designs
        constructs = Hash.new
        cnt = 0
        design.constructs.each do |c|
          cnt += 1
          constructs[cnt] = c.seq 
        end
        designs << {construct: constructs, comment: design.comment, part_id: design.part_id, part_name: design.part.name, error: nil}
      end
    end

    return designs, error
  end

  def store(designs, protocol, user_id, type)
    # parameters
    user = User.find(user_id)
    lab_id = [user.lab.id]
    design_ids = Array.new
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

    designs.each do |entry|
      design = Design.find_by_part_id_and_protocol_id(entry[:part_id], protocol.id)
      if design && type.eql?('update')
        # update record
        design.constructs.each {|c| c.destroy}
        entry[:construct].each do |i, seq|
          construct_name = entry[:part_name] + construct_suf + "_#{i}"
          design.constructs.create(:name => construct_name, :seq => seq)
        end

      elsif design.nil?
        # create new records
        design = Design.create(:part_id => entry[:part_id], :protocol_id => protocol.id, :comment => entry[:comment])
        entry[:construct].each do |i, seq|
          construct_name = entry[:part_name] + construct_suf + "_#{i}"
          design.constructs.create(:name => construct_name, :seq => seq)
        end
      end 
      design.lab_ids = (design.lab_ids + lab_id).uniq
      design.save
      design_ids << design.id
    end

    return design_ids
  end

  private
  def golden_gate(filename, processing_path, protocol, part_organism_code)
    design = {construct:nil, comment:nil, error:nil}
    part_file = "#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{filename}.fasta"
    back_trans_out = "#{processing_path}/#{filename}_backtrans.fasta"
    remove_enz_out = "#{processing_path}/#{filename}_recode.fasta"
    remove_enz_log = "#{processing_path}/#{filename}_recode.log"

    # reverse translation
    if protocol.organism.blank?
      back_trans_out = part_file
      flag = true
    else
      flag = back_trans(part_file, back_trans_out, protocol.organism_id)
    end

    # remove forbidden enzymes
    if flag
      if protocol.forbid_enzymes.blank?
        remove_enz_out = back_trans_out
        flag = true
      else
        if protocol.organism_id.blank?
          org_code = part_organism_code # no codon optimization performed when protocol.organism_id is empty
        else
          org_code = protocol.organism_id # codon organism
        end
        flag = remove_enz(back_trans_out, remove_enz_out, remove_enz_log, org_code, protocol.forbid_enzymes)
      end
    else
      design[:error] = 'Reverse translation failed! Please check if the input sequence is a protein sequence'
      return design
    end

    # retrieve recode sequence
    sequence = String.new
    if flag 
      Bio::FastaFormat.open(remove_enz_out).each {|entry| sequence = entry.seq}
    else
      design[:error] = 'Restriction enzyme substraction failed! Please check if the input sequence is a nucleotide sequence'
      return design
    end

    # check enzyme sites
    if !protocol.check_enzymes.blank?
      comments = Array.new
      protocol.check_enzymes.split(':').each do |enz|
        check_re = check_enz(sequence, enz)
        comments << "#{enz} site found at #{check_re}." if check_re
      end
      design[:comment] = comments.join(' ') unless comments.empty?
    end

    # create constructs
    if protocol.construct_size.blank?
      max_size = 1e100
    else
      max_size = protocol.construct_size
    end
    ext_prefix = '' if protocol.ext_prefix.nil?
    ext_suffix = '' if protocol.ext_suffix.nil?
    int_prefix = '' if protocol.int_prefix.nil?
    int_suffix = '' if protocol.int_suffix.nil?

    sequence = protocol.ext_prefix + sequence + protocol.ext_suffix
    if sequence.size <= max_size
      design[:construct] = {1 => sequence}
    else
      constructs = creat_frag(protocol.int_prefix, protocol.int_suffix, protocol.construct_size, sequence, protocol.overlap.split(','))
      if constructs 
        design[:construct] = constructs
      else
        design[:error] = 'Fragment creation failed!'
      end
    end

    return design
  end

  def back_trans(in_file, out_file, org_code)
    sequence = String.new 
    Bio::FastaFormat.open(in_file).each {|entry| sequence = entry.seq}
    if Bio::Sequence.auto(sequence).moltype == Bio::Sequence::NA
      return false
    else
      system "perl lib/geneDesign/Reverse_Translate.pl -i #{in_file} -o #{org_code} -w #{out_file}"
    end
  end

  def remove_enz(in_file, out_file, log_file, org_code, forbid_enz)
    # check params
    if in_file.blank? || out_file.blank? || log_file.blank? || org_code.blank? || forbid_enz.blank?
      return false
    end

    # check seq type
    sequence = String.new 
    Bio::FastaFormat.open(in_file).each {|entry| sequence = entry.seq}
    if Bio::Sequence.auto(sequence).moltype == Bio::Sequence::AA
      return false
    end

    if system "perl lib/geneDesign/Restriction_Site_Subtraction.pl -i #{in_file} -o #{org_code} -s #{forbid_enz} -w #{out_file} -t 10 > #{log_file}"
      if File.open(log_file, 'r').read.include?('unable')
        return false
      else
        return true
      end
    else
      return false
    end
  end

  def check_enz(sequence, enzyme)
    out = `python enz_site.py -seq #{sequence} -e #{enzyme}`
    if out.empty? || out.include?('false')
      return false
    else
      return out.delete("\n")
    end
  end

  def creat_frag(int_pre, int_suf, max_size, seq, overlaps)
    # create allowed overlap list
    allowed_overlaps =  Array.new
    overlaps.each do |entry|
      allowed_overlaps << entry.upcase
      allowed_overlaps << Bio::Sequence::NA.new(entry).complement.to_s.upcase
    end
    allowed_overlaps.uniq!
    # adjust fragment size to avoid small fagment
    frag_size = max_size - int_pre.size - int_suf.size
    frag_num = (seq.size.to_f / frag_size).ceil
    frag_size = seq.size / frag_num
    # create construct
    construct = Hash.new
    cnt = 0
    seq_remain = seq.upcase
    while cnt < frag_num
      cnt += 1
      if cnt == frag_num
        construct[cnt] = int_pre + seq_remain
      else
        re = create_overlap(allowed_overlaps, seq_remain[0, frag_size], seq_remain[frag_size..-1])
        if re
          if cnt == 1
            construct[cnt] = re['seq_left'] + int_suf
          else
            construct[cnt] = int_pre + re['seq_left'] + int_suf
          end
          seq_remain = re['seq_right']
          allowed_overlaps.delete_at(allowed_overlaps.index(re['overlap']))
          allowed_overlaps.delete_at(allowed_overlaps.index(Bio::Sequence::NA.new(re['overlap']).complement.to_s.upcase))
        else
          return false
        end
      end
    end
    return construct
  end

  def create_overlap(allowed_overlaps, seq_left, seq_right)
    ol_size = allowed_overlaps[0].size
    shift = 0
    while shift < seq_left.size/2 && shift < seq_right.size/2
      # shift left
      new_left = seq_left[0, (seq_left.size - shift)]
      new_right = seq_left[(seq_left.size - shift), shift] + seq_right
      overlap = new_left[(new_left.size - ol_size), ol_size]
      if allowed_overlaps.include?(overlap)
        return {'seq_left' => new_left, 'seq_right' => (overlap + new_right), 'overlap' => overlap}
      end
      # shift right
      new_left = seq_left + seq_right[0, shift]
      new_right = seq_right[shift..-1]
      overlap = new_left[(new_left.size - ol_size), ol_size]
      if allowed_overlaps.include?(overlap)
        return {'seq_left' => new_left, 'seq_right' => (overlap + new_right), 'overlap' => overlap}
      end
      # no overlap found  
      shift += 1
    end
    return false    
  end

end
