require 'bio'

class BioDesign

  def initialize(protein_file, processing_path, protocol)
    @@design = {construct:nil, comment:nil, error:nil}
    protein_filename = protein_file.split('/')[-1].chomp('.fasta') 
    back_trans_out = "#{processing_path}/#{protein_filename}_backtrans.fasta"
    remove_enz_out = "#{processing_path}/#{protein_filename}_recode.fasta"
    remove_enz_log = "#{processing_path}/#{protein_filename}_recode.log"
    # reverse translation
    flag = back_trans(protein_file, back_trans_out, protocol.organism_id)
    # remove forbidden enzymes
    if flag
      flag = remove_enz(back_trans_out, remove_enz_out, remove_enz_log, protocol.organism_id, protocol.forbid_enzymes)
    else
      return @@design[:error] = 'Reverse translation failed!'
    end
    # retrieve recode sequence
    sequence = String.new
    if flag 
      Bio::FastaFormat.open(remove_enz_out).each {|entry| sequence = entry.seq}
    else
      return @@design[:error] = 'Restriction enzyme substraction failed!'
    end
    # check enzyme sites
    if !protocol.check_enzymes.nil? && !protocol.check_enzymes.empty?
      comments = Array.new
      protocol.check_enzymes.split(':').each do |enz|
        check_re = check_enz(sequence, enz)
        comments << "#{enz} site found at #{check_re}." if check_re
      end
      @@design[:comment] = comments.join(' ') unless comments.empty?
    end
    # create constructs
    sequence = protocol.ext_prefix + sequence + protocol.ext_suffix
    if sequence.size <= protocol.construct_size
      @@design[:construct] = {1 => sequence}
    else
      constructs = creat_frag(protocol.int_prefix, protocol.int_suffix, protocol.construct_size, sequence, protocol.overlap.split(','))
      if constructs 
        @@design[:construct] = constructs
      else
        @@design[:error] = 'Fragment creation failed!'
      end
    end
  end

  def back_trans(in_file, out_file, org_code)
    system "perl lib/geneDesign/Reverse_Translate.pl -i #{in_file} -o #{org_code} -w #{out_file}"
  end

  def remove_enz(in_file, out_file, log_file, org_code, forbid_enz)
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
    out = `python restriction_enz_site.py -seq #{sequence} -e #{enzyme}`
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

  def to_s
    @@design
  end

  private
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
