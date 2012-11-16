class NewPart
  @queue = :partsbuilder_new_part_queue

  def self.perform(accession)

    require 'xmlsimple' 

    # retrieve data from NCBI
    Bio::NCBI.default_email = 'synbio@jhu.edu'
    begin
      ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"gp", "retmode" => "xml"})
      puts "retrieve sequence #{accession} succeed"
    rescue
      puts "retrieve sequence #{accession} failed"
      return false
    end   

    # process data
    xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
    if xml['GBSeq']['GBSeq_sequence'].nil?
      return false
    else
      seq = xml['GBSeq']['GBSeq_sequence'].upcase
    end

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

    if ! xml['GBSeq']['GBSeq_organism'].nil?
      org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
      org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
      organism = Organism.where("fullname = ?", org_name)
      if organism.empty?
        organism = Organism.create(:fullname => org_name, :name => org_abbr)
        organism_id = organism.id
      else
        organism.each {|entry| organism_id = entry.id}
      end
    else
      org_name = ""
      org_abbr = ""
      organism_id = NULL
    end

    # store retrieve data
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
