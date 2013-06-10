require 'xmlsimple' 
require 'csv'

class AutoBuild
  include Sidekiq::Worker

  def perform(para)

    Bio::NCBI.default_email = 'synbio@jhu.edu'

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    error_info = String.new
    #################### MAIN START ##########################

    ################## New Part Start ########################
    is_new_part_success = true
    part_id_list = Array.new
    if para['accession'] == "none"
      in_file = Bio::FastaFormat.open(para['seq_file'], 'r')
      # retrieve data from FASTA file
      in_file.each do |entry|
        seq = String.new
        org_name = ""
        org_abbr = ""
        organism_id = nil 

        if entry.seq.empty? || Bio::Sequence.auto(entry.seq).moltype != Bio::Sequence::AA
          is_new_part_success = false
          error_info << "Invalidate Format: must be AA sequence! "
          break
        else
          seq_descript_array = entry.definition.split('|')
          if seq_descript_array.length == 2
            part_name = seq_descript_array[0].strip
            accession = seq_descript_array[1].strip
            seq = entry.seq.upcase
          elsif seq_descript_array.length >= 3
            part_name = seq_descript_array[0].strip
            accession = seq_descript_array[1].strip
            seq = entry.seq.upcase
            org_name = seq_descript_array[2]
            unless org_name.empty?
              org_name.strip!
              if org_name.split(' ').length < 2
                org_abbr = org_name
              else
                org_abbr = org_name.split(' ')[0][0].upcase + org_name.split(' ')[1][0,2].downcase
              end
            end
          else
            is_new_part_success = false
            error_info << "Invalidate Format: #{entry.definition}! "
            break
          end
        end

        # store retrieved data
        if is_new_part_success
          exist_part = Sequence.find_by_accession(accession)
          if exist_part.nil?
            if ! org_name.empty?
              organism = Organism.find_by_fullname(org_name) || Organism.create(:fullname => org_name, :name => org_abbr)
              organism_id = organism.id
            end
            part = Part.create(:name => part_name)
            part_id_list << part.id
            Sequence.create(:accession => accession, :organism_id => organism_id, :part_id => part.id, :seq => seq, :annotation => "CDS")

            # create protein fasta file for GeneDesign
            fasta_seq = Bio::Sequence.new(seq)
            f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{accession}.fasta", 'w')
            f.print fasta_seq.output(:fasta, :header => part_name, :width => 80)
            f.close
          else
            part_id_list << exist_part.id
          end
        end
        # end of retrieving one sequence from FASTA file 
      end
      # if a list of accession numbers submitted instead of a FASTA file
    else
      accession_list = para['accession']
      accession_list.each do |accession|
        accession.strip!
        if (! accession.empty?) && is_new_part_success
          exist_part = Sequence.find_by_accession(accession)
          unless exist_part.nil?
            part_id_list << exist_part.id
          else
            # retrieve data from NCBI
            begin
              ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"fasta"})
              if ncbi.include?("Cannot process")
                error_info << "Bad ID: #{accession}! "
                is_new_part_success = false
              elsif ncbi.include?("Bad Gateway")
                error_info << "NCBI is temporarily unavailable. Please try later! "
                is_new_part_success = false
              end
            rescue
              error_info << "Retrieve #{accession} failed! "
              is_new_part_success = false
            end    

            if is_new_part_success
              # set initial value for variables that will be stored in the database
              geneName = String.new
              seq = String.new
              org_name = ""
              org_abbr = ""
              organism_id = nil

              # check accession number type, protein or nucleotide
              ncbi_fasta = Bio::FastaFormat.new(ncbi)
              ncbi_seq = Bio::Sequence.auto(ncbi_fasta.seq)
              if ncbi_seq.moltype == Bio::Sequence::NA

                # when nucleotide
                begin
                  ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"nucleotide", "rettype"=>"gb", "retmode" => "xml"})
                  if ncbi.include?("Bad Gateway")
                    error_info << "NCBI is temporarily unavailable. Please try later! "
                    is_new_part_success = false
                  end
                rescue
                  error_info << "Retrieve #{accession} failed! "
                  is_new_part_success = false
                end

                # retrieve data from xml
                if is_new_part_success
                  xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
                  # get organism
                  if (! xml['GBSeq'].nil?) && (! xml['GBSeq']['GBSeq_organism'].nil?)
                    org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
                    org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
                  end
                  # get gene name and sequence	
                  cds_num = 0
                  if (! xml['GBSeq'].nil?) && (! xml['GBSeq']['GBSeq_feature-table'].nil?) && (! xml['GBSeq']['GBSeq_feature-table']['GBFeature'].nil?)  
                    xml['GBSeq']['GBSeq_feature-table']['GBFeature'].each do |entry|
                      if entry.class == Hash && entry.has_value?("CDS")
                        cds_num += 1
                        # if has more than one CDS, rejected
                        if cds_num > 1
                          error_info << "Rejected: Requested accession #{accession} contains >1 CDS! "
                          is_new_part_success = false
                          break
                        end
                        if (! entry['GBFeature_quals'].nil?) && (! entry['GBFeature_quals']['GBQualifier'].nil?)
                          entry['GBFeature_quals']['GBQualifier'].each do |sub_entry|
                            if sub_entry.class == Hash && sub_entry['GBQualifier_name'] == "gene"
                              geneName = sub_entry['GBQualifier_value'] || ""
                            end
                            if sub_entry.class == Hash && sub_entry['GBQualifier_name'] == "translation"
                              seq = sub_entry['GBQualifier_value'].upcase || ""
                            end
                          end
                        end
                      end
                    end
                  end
                end # end of retrieving gene name and sequence

              else
                # when protein
                begin
                  ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"gp", "retmode" => "xml"})
                  if ncbi.include?("Bad Gateway")
                    error_info << "NCBI is temporarily unavailable. Please try later! "
                    is_new_part_success = false
                  end
                rescue
                  error_info << "Retrieve #{accession} failed! "
                  is_new_part_success = false
                end

                # retrieve data from xml
                if is_new_part_success
                  xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
                  # get organism
                  if (! xml['GBSeq'].nil?) && (! xml['GBSeq']['GBSeq_organism'].nil?)
                    org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
                    org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
                  end
                  # get gene name and sequence	
                  seq = ncbi_fasta.seq.upcase
                  if (! xml['GBSeq'].nil?) && (! xml['GBSeq']['GBSeq_feature-table'].nil?) && (! xml['GBSeq']['GBSeq_feature-table']['GBFeature'].nil?)
                    xml['GBSeq']['GBSeq_feature-table']['GBFeature'].each do |entry|
                      if (! entry["GBFeature_quals"].nil?) && (! entry["GBFeature_quals"]["GBQualifier"].nil?)
                        entry["GBFeature_quals"]["GBQualifier"].each do |sub_entry|
                          if sub_entry.class == Hash && sub_entry["GBQualifier_name"] == "gene"
                            geneName = sub_entry["GBQualifier_value"] || ""
                            break
                          end   
                        end   
                      end   
                    end   
                  end
                end

              end # end of retrieving data from ncbi

              # store retrieved data
              if is_new_part_success
                if seq.empty?
                  error_info << "Retrieve #{accession} failed! "
                  is_new_part_success = false
                else
                  if ! org_name.empty?
                    organism = Organism.find_by_fullname(org_name) || Organism.create(:fullname => org_name, :name => org_abbr)
                    organism_id = organism.id
                  end
                  part_name = "CDS_#{org_abbr}_#{geneName}_#{accession}"
                  part = Part.create(:name => part_name)
                  part_id_list << part.id
                  Sequence.create(:accession => accession, :organism_id => organism_id, :part_id => part.id, :seq => seq, :annotation => "CDS")

                  # create protein fasta file for GeneDesign
                  fasta_seq = Bio::Sequence.new(seq)
                  f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{accession}.fasta", 'w')
                  f.print fasta_seq.output(:fasta, :header => part_name, :width => 80)
                  f.close
                end
              end
            end

          end
        end
      end
    end
    ################### New Part End #########################

    ################# New Design Start #######################
    is_new_design_success = true
    design_id_list = Array.new
    unless is_new_part_success
      is_new_design_success = false
    else
      part_id_list.each do |part_id|
        if is_new_design_success 
          exist_design = Design.find_by_part_id_and_protocol_id(part_id, para['protocol_id'])
          unless exist_design.nil?
            design_id_list << exist_design.id	
          else
            design = Design.create(:part_id => part_id, :protocol_id => para['protocol_id'])
            design_id_list << design.id

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
            begin
              system "perl #{geneDesign_path}/Reverse_Translate.pl -i #{protein_path}/#{accession}.fasta -o #{org_code} -w #{process_path}/#{accession}_backtrans.fasta"
            rescue
              error_info << "There is something wrong with reverse translation. Please contact administor! "
              is_new_design_success = false
            end

            # remove forbidden enzymes
            begin
              system "perl #{geneDesign_path}/Restriction_Site_Subtraction.pl -i #{process_path}/#{accession}_backtrans.fasta -o #{org_code} -s #{forbid_enzymes} -w #{process_path}/#{accession}_recode.fasta -t 10 > #{process_path}/#{accession}_recode.out"
            rescue
              error_info << "There is something wrong with restriction site substraction. Please contact administor! "
              is_new_design_success = false
            end

            if is_new_design_success
              recode_out = File.open("#{process_path}/#{accession}_recode.out", 'r')
              if recode_out.read.include?('unable')
                error_info << "There is something wrong with restriction site substraction. Please contact administor! "
                is_new_design_success = false
              end
              recode_out.close
            end

            if is_new_design_success
              recode_file = Bio::FastaFormat.open("#{process_path}/#{accession}_recode.fasta")
              recode_seq = String.new
              recode_file.each {|entry| recode_seq = entry.seq.to_s}
            end

            # check enzyme sites
            if ! check_enzymes.empty? && is_new_design_success
              begin
                system "perl #{geneDesign_path}/Restriction_Site_Subtraction.pl -i #{process_path}/#{accession}_recode.fasta -o #{org_code} -s #{check_enzymes} -w #{process_path}/#{accession}_check.fasta -t 10"
              rescue
                error_info << "There is something wrong with checking restriction enzyme sites. Please contact administor! "
                is_new_design_success = false
              end
              if is_new_design_success
                check_file = Bio::FastaFormat.open("#{process_path}/#{accession}_check.fasta")
                check_file.each do |entry| 
                  if entry.seq.to_s != recode_seq
                    comment << "Restriction sites of #{check_enzymes.gsub(/:/, ', ')} found! "
                  end
                end
              end
            end

            if is_new_design_success
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
                while i < frag_num && is_new_design_success
                  i += 1
                  overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
                  stop_site_before_shift = stop_site
                  cnt = 0 

                  # find unique overlap
                  while (! allowable_overlap.include?(overlap)) && (i != frag_num) && is_new_design_success do
                    # if overlap is not unique, move +-n bp to find unique overlap 
                    # shift = -1, 1, -2, 2, -3, 3, -4, 4 .....
                    cnt += 1
                    shift = (cnt/2 + cnt%2) * ((-1) ** cnt)
                    # if cannot find unique overlap, report failure
                    if (shift.abs > frag_size) || (stop_site_before_shift + shift >= recode_seq.length)
                      comment << "Resize Failed! "
                      error_info << "Resize #{design.part.name} Failed! No unique overlap found! "
                      is_new_design_success = false               
                    end 
                    stop_site = stop_site_before_shift + shift
                    overlap = recode_seq[(stop_site - overlap_size + 1), overlap_size]
                  end

                  if is_new_design_success
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
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    ################## New Design End ########################

    ################## New Order Start #######################
    is_new_order_success = true
    unless is_new_design_success
      is_new_order_success = false
    else
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
      total_parts = 0
      total_bp = 0

      design_id_list.each do |design_id|
        design = Design.find(design_id)

        design.construct.each do |construct|
          sequence = Bio::Sequence.new(construct.seq)
          total_parts += 1
          total_bp += construct.seq.length

          csv_file << ["#{construct.name}", "#{construct.seq.length}", "#{construct.comment || 'none'}", "#{construct.seq}"]
          seq_file.print sequence.output(:fasta, :header => construct.name, :width => 80)
        end
      end

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
    end
    ################### New Order End ########################

    ##################### MAIN END ###########################
    # change job status
    if is_new_order_success
      job.change_status('finished')
    else
      job.change_status('failed')
      job.error_info = error_info
      job.save
    end
    # send email notice
    order = Order.find(para['order_id'])
    PartsbuilderMailer.finished_notice(order.user, error_info).deliver

  end 

end
