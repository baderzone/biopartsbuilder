class DesignPart
  @queue = :partsbuilder_design_part_queue

  def self.perform(design_id)

    design = Design.find(design_id)

    process_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
    protein_path = "#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}"
    geneDesign_path = "#{PARTSBUILDER_CONFIG['program']['geneDesign_path']}"
    ext_prefix = design.protocol.ext_prefix
    int_prefix = design.protocol.int_prefix
    ext_suffix = design.protocol.ext_suffix
    int_suffix = design.protocol.int_suffix
    enzymes = design.protocol.rs_enz
    seq_size = design.protocol.construct_size
    overlap_list = design.protocol.overlap.split(',')
    org_code = design.protocol.organism.id

    # back translate prtoein sequence
    system "perl #{geneDesign_path}/Reverse_Translate.pl -i #{protein_path}/#{design.part.sequence.accession}.fasta -o #{org_code} -w #{process_path}/#{design.part.sequence.accession}_backtrans.fasta"

    # remove forbidden enzymes
    system "perl #{geneDesign_path}/Restriction_Site_Subtraction.pl -i #{process_path}/#{design.part.sequence.accession}_backtrans.fasta -o #{org_code} -s #{enzymes} -w #{process_path}/#{design.part.sequence.accession}_recode.fasta -t 10"
    recode_file = Bio::FastaFormat.open("#{process_path}/#{design.part.sequence.accession}_recode.fasta")
    recode_seq = String.new
    recode_file.each {|entry| recode_seq = entry.seq.to_s}
    recode_seq = ext_prefix + recode_seq + ext_suffix

    # check sequence length, if longer than maximum, carve it
    if recode_seq.length < seq_size
      construct = Construct.create(:design_id => design_id, :name => "#{design.part.name}_COy", :seq => recode_seq)

    else
      # produce allowable overlap array
      overlap_list_complement = Array.new
      overlap_list.each do |entry|
        overlap_list_complement << Bio::Sequence::NA.new(entry).complement.to_s.upcase
      end
      allowable_overlap = overlap_list + overlap_list_complement
      allowable_overlap.uniq!
      overlap_size = allowable_overlap[0].length
      # modify fragment size to avoid small fragment
      frag_num = (recode_seq.length.to_f/(seq_size - int_prefix.length - int_suffix.length)).ceil
      frag_size = recode_seq.length/frag_num
      # check overlap
      start_site = 0 
      stop_site = start_site + frag_size
      for i in (1..frag_num).to_a
        overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
        flag = stop_site
        cnt = 0 
        # find unique overlap
        while (! allowable_overlap.include?(overlap)) && (i != frag_num) do
          cnt += 1
          shift = (cnt/2 + cnt%2) * ((-1) ** cnt)
          if (shift.abs > frag_size) || (flag+shift >= recode_seq.length)
            return false   # cannot find unique overlap
          end 
          stop_site = flag + shift
          overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
        end
        if i != frag_num
          if i == 1
            construct_seq = (recode_seq[start_site, (stop_site-start_site+1)]).to_s + int_suffix
          else
            construct_seq = int_prefix + (recode_seq[start_site, (stop_site-start_site+1)]).to_s + int_suffix
          end
          construct = Construct.create(:design_id => design_id, :name => "#{design.part.name}_COy_#{i}", :seq => construct_seq)
          # remove this overlap from allowable overlap list
          allowable_overlap.delete_at(allowable_overlap.index(overlap))
          overlap_complement = Bio::Sequence::NA.new(overlap).complement.to_s.upcase
          allowable_overlap.delete_at(allowable_overlap.index(overlap_complement))
          start_site = stop_site - overlap_size + 1
          stop_site = start_site + frag_size
        else
          construct_seq = int_prefix + (recode_seq[start_site, recode_seq.length]).to_s
          construct = Construct.create(:design_id => design_id, :name => "#{design.part.name}_COy_#{i}", :seq => construct_seq)
        end
      end
    end
  end

end
