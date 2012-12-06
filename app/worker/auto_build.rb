class AutoBuild
  @queue = :partsbuilder_auto_build_queue

  def self.perform(para)

    require 'xmlsimple' 
    require 'csv'

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    error_info = String.new

    # parameters
    Bio::NCBI.default_email = 'synbio@jhu.edu'

    order_path = "#{PARTSBUILDER_CONFIG['program']['order_path']}"
    system "mkdir #{order_path}/#{para['order_id']}"
    result_path = "#{PARTSBUILDER_CONFIG['program']['order_path']}/#{para['order_id']}"

    zip_file_name = "order#{para['order_id']}.zip"
    csv_file_name = "order#{para['order_id']}_all.csv"
    seq_file_name = "order#{para['order_id']}_seq.fasta"
    sum_file_name = "order#{para['order_id']}_summary.txt"

    csv_file = CSV.open("#{result_path}/#{csv_file_name}", 'w')
    seq_file = File.new("#{result_path}/#{seq_file_name}", 'w')
    sum_file = File.new("#{result_path}/#{sum_file_name}", 'w')

    csv_file << ["Part Name", "Length", "Comment", "Part Sequence"]
    total_parts = 0 # count how many parts are made
    total_bp = 0    # count how many base pairs are designed

    # main
    accession_list = para['accession']
    accession_list.each do |accession|
      accession.strip!
      if ! accession.empty?

        ######################
        # start create parts #
        # ####################
        part = Part.find_by_sequence_accession(accession)
        if part.nil?
          # retrieve data from NCBI
          is_ncbi_success = true
          begin
            ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"gp", "retmode" => "xml"})
            if ncbi.include?("ERROR")
              is_ncbi_success = false
              error_info << "Bad ID: #{accession}! "
            end
          rescue
            is_ncbi_success = false
            error_info << "Retrieve #{accession} failed! "
          end   

          # process ncbi data
          # get gene sequence 
          if is_ncbi_success
            xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
            if xml['GBSeq']['GBSeq_sequence'].nil?
              return false
            else
              seq = xml['GBSeq']['GBSeq_sequence'].upcase
            end
            # get gene symbol 
            geneName = String.new
            if ! xml['GBSeq']['GBSeq_feature-table']['GBFeature'].nil?
              xml['GBSeq']['GBSeq_feature-table']['GBFeature'].each do |entry|
                if ! entry["GBFeature_quals"]["GBQualifier"].nil?
                  entry["GBFeature_quals"]["GBQualifier"].each do |item|
                    if item.class == Hash
                      if item["GBQualifier_name"] == "gene"
                        geneName = item["GBQualifier_value"]
                        break;
                      end   
                    end   
                  end   
                end   
              end   
            end
            # get gene organism 
            if ! xml['GBSeq']['GBSeq_organism'].nil?
              org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
              org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
              # if new organism, add to organisms table 
              organism = Organism.find_by_fullname(org_name) || Organism.create(:fullname => org_name, :name => org_abbr)
              organism_id = organism.id
            else
              org_name = ""
              org_abbr = ""
              organism_id = nil
            end

            # store retrieved data
            part_name = "CDS_#{org_abbr}_#{geneName}_#{accession}"
            part = Part.create(:name => part_name)
            Sequence.create(:accession => accession, :organism_id => organism_id, :part_id => part.id, :seq => seq, :annotation => "CDS")

            # create protein fasta file for GeneDesign
            fasta_seq = Bio::Sequence.new(seq)
            f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{accession}.fasta", 'w')
            f.print fasta_seq.output(:fasta, :header => part_name, :width => 80)
            f.close

          end # end of retrieving data from ncbi
        end #  end of creating parts
        
        #####################
        # start design part #
        # ###################
        design = Design.find_by_part_id_and_protocol_id(part.id, para['protocol_id'])
        if design.nil?
          design = Design.create(:part_id => part.id, :protocol_id => para['protocol_id'])
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
        end # end of designing parts

        ######################
        # start create order #
        # ###################
        design.construct.each do |construct|
          sequence = Bio::Sequence.new(construct.seq)
          total_parts += 1
          total_bp += construct.seq.length

          csv_file << ["#{construct.name}", "#{construct.seq.length}", "#{construct.comment || 'none'}", "#{construct.seq}"]
          seq_file.print sequence.output(:fasta, :header => construct.name, :width => 80)
        end # end of creating order for one part 

      end # end of auto_build one part  
    puts "part #{accession} designed!"
    end # end of auto_build all parts

    # create summary file and zip file
    sum_file.puts "Total parts made: #{total_parts}"
    sum_file.puts "Total bp designed: #{total_bp}"

    csv_file.close
    seq_file.close
    sum_file.close

    Zip::ZipFile.open("#{result_path}/#{zip_file_name}", Zip::ZipFile::CREATE) do |ar|
      ar.add(csv_file_name, "#{result_path}/#{csv_file_name}")
      ar.add(seq_file_name, "#{result_path}/#{seq_file_name}")
      ar.add(sum_file_name, "#{result_path}/#{sum_file_name}")
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
    order = Order.find(para['order_id'])
    PartsbuilderMailer.finished_notice(order.user).deliver

  end 

end
