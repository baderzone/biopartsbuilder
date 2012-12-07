class NewPart
  extend Resque::Plugins::Logger
  @queue = :partsbuilder_new_part_queue

  def self.perform(para)

    require 'xmlsimple' 
    Bio::NCBI.default_email = 'synbio@jhu.edu'

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    error_info = String.new

    accession_list = para['accession']
    accession_list.each do |accession|
      accession.strip!
      if (! accession.empty?) && (Sequence.find_by_accession(accession).nil?)
        is_ncbi_success = true
        # retrieve data from NCBI
        begin
          ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"gp", "retmode" => "xml"})
          if ncbi.include?("ERROR")
            is_ncbi_success = false
            logger.info("Bad ID: #{accession}!")
            error_info << "Bad ID: #{accession}! "
          else
            logger.info("#{accession}! retrieved")
          end
        rescue
          is_ncbi_success = false
          logger.info("Retrieve #{accession} failed!")
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

        end
      end
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
    current_user = User.find(para['user_id'])
    PartsbuilderMailer.finished_notice(current_user).deliver

  end

end
