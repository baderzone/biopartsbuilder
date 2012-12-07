class DesignPart
  extend Resque::Plugins::Logger
  @queue = :partsbuilder_design_part_queue

  def self.perform(para)

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    error_info = String.new

    part_id_list = para['part_id']
    part_id_list.each do |part_id|
      if Design.find_by_part_id_and_protocol_id(part_id, para['protocol_id']).nil?
        design = Design.create(:part_id => part_id, :protocol_id => para['protocol_id'])

        # parameters
        process_path = "#{PARTSBUILDER_CONFIG['program']['partsbuilder_processing_path']}"
        protein_path = "#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}"
        geneDesign_path = "#{PARTSBUILDER_CONFIG['program']['geneDesign_path']}"
        ext_prefix = design.protocol.ext_prefix
        int_prefix = design.protocol.int_prefix
        ext_suffix = design.protocol.ext_suffix
        int_suffix = design.protocol.int_suffix
        forbid_enzymes = design.protocol.forbid_enzymes
        check_enzymes = design.protocol.check_enzymes || ""
        seq_size = design.protocol.construct_size
        overlap_list = design.protocol.overlap.split(',')
        org_code = design.protocol.organism.id
        accession = design.part.sequence.accession
        comment = String.new

        # back translate prtoein sequence
        system "perl #{geneDesign_path}/Reverse_Translate.pl -i #{protein_path}/#{accession}.fasta -o #{org_code} -w #{process_path}/#{accession}_backtrans.fasta"

        # remove forbidden enzymes
        system "perl #{geneDesign_path}/Restriction_Site_Subtraction.pl -i #{process_path}/#{accession}_backtrans.fasta -o #{org_code} -s #{forbid_enzymes} -w #{process_path}/#{accession}_recode.fasta -t 10"
        recode_file = Bio::FastaFormat.open("#{process_path}/#{accession}_recode.fasta")
        recode_seq = String.new
        recode_file.each {|entry| recode_seq = entry.seq.to_s}

        # check enzyme sites
        if ! check_enzymes.empty?
          system "perl #{geneDesign_path}/Restriction_Site_Subtraction.pl -i #{process_path}/#{accession}_recode.fasta -o #{org_code} -s #{check_enzymes} -w #{process_path}/#{accession}_check.fasta -t 10"
          check_file = Bio::FastaFormat.open("#{process_path}/#{accession}_check.fasta")
          check_file.each do |entry| 
            if entry.seq.to_s != recode_seq
              comment << "Restriction sites of #{check_enzymes.gsub(/:/, ', ')} found! "
            end
          end
        end

        recode_seq = ext_prefix + recode_seq + ext_suffix
        # check sequence length, if longer than maximum, carve it
        if recode_seq.length < seq_size
          construct = Construct.create(:design_id => design.id, :name => "#{design.part.name}_COy", :seq => recode_seq, :comment => comment)

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
          i = 0
          while i < frag_num
            i += 1
            overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
            stop_site_before_shift = stop_site
            cnt = 0 

            # find unique overlap
            while (! allowable_overlap.include?(overlap)) && (i != frag_num) do
              # if overlap is not unique, move +-n bp to find unique overlap 
              # shift = -1, 1, -2, 2, -3, 3, -4, 4 .....
              cnt += 1
              shift = (cnt/2 + cnt%2) * ((-1) ** cnt)
              # if cannot find unique overlap, report failure
              if (shift.abs > frag_size) || (stop_site_before_shift + shift >= recode_seq.length)
                comment << "Resize Failed! "
                error_info << "Resize #{design.part.name} Failed! No unique overlap found! "
                logger.info("Resize #{design.part.name} Failed! No unique overlap found!")
                i = frag_num
                break;   
              end 
              stop_site = stop_site_before_shift + shift
              overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
            end

            if i != frag_num
              if i == 1
                construct_seq = (recode_seq[start_site, (stop_site-start_site+1)]).to_s + int_suffix
              else
                construct_seq = int_prefix + (recode_seq[start_site, (stop_site-start_site+1)]).to_s + int_suffix
              end
              construct = Construct.create(:design_id => design.id, :name => "#{design.part.name}_COy_#{i}", :seq => construct_seq, :comment => comment)

              # remove this overlap from allowable overlap list
              allowable_overlap.delete_at(allowable_overlap.index(overlap))
              overlap_complement = Bio::Sequence::NA.new(overlap).complement.to_s.upcase
              allowable_overlap.delete_at(allowable_overlap.index(overlap_complement))
              # renew start_site, stop_site
              start_site = stop_site - overlap_size + 1
              stop_site = start_site + frag_size

            else
              # last fragment
              construct_seq = int_prefix + (recode_seq[start_site, recode_seq.length]).to_s
              construct = Construct.create(:design_id => design.id, :name => "#{design.part.name}_COy_#{i}", :seq => construct_seq, :comment => comment)
              break;
            end
          end
        end
      end
    end
    # change job status
    if error_info.empty?
      job.change_status('finished')
      logger.info("#{design.part.name} Designed! ")
    else
      job.change_status('failed')
      job.error_info = error_info
      job.save
    end
    # send email notice
    current_user = User.find(para['user_id'])
    PartsbuilderMailer.finished_notice(current_user).deliver

  end

end
