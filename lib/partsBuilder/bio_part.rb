require 'xmlsimple'

class BioPart

  def retrieve(input, type)
    bioparts = Array.new
    error = String.new

    case type
    when 'fasta'
      in_file = Bio::FastaFormat.open(input, 'r')
      in_file.each do |entry|
        biopart = create_from_fasta(entry)
        bioparts << biopart
      end 
      in_file.close
    when 'ncbi'
      input.each do |entry|
        sequence = Sequence.find_by_accession(entry)
        if sequence.nil?
          # create new sequence
          biopart = create_from_ncbi(entry)
          if biopart[:error].nil?
            bioparts << biopart
          else
            error = biopart[:error]
            return bioparts, error
          end
        else
          # retrieve exist data
          bioparts << {name: sequence.part.name, type: sequence.part.name.split('_')[0], seq: sequence.seq, accession_num: sequence.accession, org_latin: sequence.organism.fullname, org_abbr: sequence.organism.name, comment: sequence.part.comment} 
        end 
      end 
    end

    return bioparts, error 
  end

  def check(bioparts)
    error = String.new
    bioparts.each do |entry|
      exist_seq = Sequence.find_by_accession(entry[:accession_num])
      if !exist_seq.nil?
        if exist_seq.seq != entry[:seq]
          error = "Part '#{entry[:accession_num]}' with different sequence found!  Please check if the data is correct. Accession number must be unique (one sequence, one number). The sequence of part found in the database is: #{exist_seq.seq}. The sequence of your part is: #{entry[:seq]}"
          return error
        end
      end
    end

    return error
  end

  def store(bioparts)
    part_ids = Array.new

    bioparts.each do |entry|
      if ! entry[:org_latin].nil?
        organism = Organism.find_by_fullname(entry[:org_latin],) || Organism.create(:fullname => entry[:org_latin], :name => entry[:org_abbr])
      end
      sequence = Sequence.find_by_accession(entry[:accession_num])
      if sequence.nil?
        part = Part.create(:name => entry[:name].gsub(/__/, '_'), :comment => entry[:comment])
        part.create_sequence(:accession => entry[:accession_num], :organism => organism, :seq => entry[:seq], :annotation => entry[:type])
        part_ids << part.id

        # create protein fasta file for GeneDesign
        fasta_seq = Bio::Sequence.new(entry[:seq])
        f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{entry[:accession_num]}.fasta", 'w')
        f.print fasta_seq.output(:fasta, :header => part.name, :width => 80)
        f.close
      else
        part_ids << sequence.part.id
      end
    end

    return part_ids
  end


  private
  def create_from_fasta(entry)
    part = {name: nil, type: nil, seq: nil, accession_num: nil, org_latin: nil, org_abbr: nil, comment: nil}
    descriptions = entry.definition.split('|')
    gene_name = descriptions[0].strip

    part[:type] = descriptions[1].strip
    part[:accession_num] = descriptions[2].strip
    part[:org_latin] = descriptions[3] && descriptions[3].strip
    part[:org_abbr] = part[:org_latin].split(' ')[0][0].upcase + part[:org_latin].split(' ')[1][0, 2].downcase unless part[:org_latin].nil?
    part[:comment] = descriptions[4] && descriptions[4].strip
    part[:name] = "#{part[:type]}_#{part[:org_abbr]}_#{gene_name}_#{part[:accession_num]}"
    part[:seq] = entry.seq.upcase
    return part
  end

  def create_from_ncbi(accession)
    part = {name: nil, type: nil, seq: nil, accession_num: nil, org_latin: nil, org_abbr: nil, comment: nil}
    Bio::NCBI.default_email = 'synbio@jhu.edu'
    part[:accession_num] = accession
    part[:type] = 'CDS'

    begin
      ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"nucleotide", "rettype"=>"gb", "retmode" => "xml"})
      if ncbi.include?("Cannot process")
        return {error: "Bad ID: #{accession}!"}
      elsif ncbi.include?("Bad Gateway")
        return {error: "NCBI is temporarily unavailable. Please try later!"}
      end 
    rescue
      return {error: "Retrieve #{accession} failed, cannot connect to NCBI.  Please check your network access and try again!"}
    end    

    xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})

    # check CDS number
    features = get_value(xml, 'GBSeq', 'GBSeq_feature-table', 'GBFeature')
    cds_num = 0
    features.each {|hash| cds_num += 1 if hash.has_value?('CDS')} unless features.nil?
    return {error: "Rejected: Requested accession #{accession} contains >1 CDS!"} if cds_num > 1

    # get organism
    org = get_value(xml, 'GBSeq', 'GBSeq_organism')
    if !org.nil?
      part[:org_latin] = org.split(' ')[0, 2].join(' ')
      part[:org_abbr] = part[:org_latin].split(' ')[0][0].upcase + part[:org_latin].split(' ')[1][0, 2].downcase
    end

    # get gene name
    features.each do |f|
      quals = get_value(f, 'GBFeature_quals', 'GBQualifier')
      quals.each do |entry|
        if get_value(entry, 'GBQualifier_name') == "gene" && !get_value(entry, 'GBQualifier_value').nil?
          part[:name] = "CDS_#{part[:org_abbr]}_#{get_value(entry, 'GBQualifier_value')}_#{accession}"
          break
        end
      end unless quals.nil?
      break unless part[:name].nil?
    end unless features.nil?
    part[:name] = "CDS_#{part[:org_abbr]}_#{accession}" if part[:name].nil?

    # get sequence
    if get_value(xml, 'GBSeq', 'GBSeq_moltype') == 'AA'
      part[:seq] = get_value(xml, 'GBSeq', 'GBSeq_sequence') 
    else
      features.each do |f|
        quals = get_value(f, 'GBFeature_quals', 'GBQualifier')
        quals.each do |entry|
          if get_value(entry, 'GBQualifier_name') == "translation" && !get_value(entry, 'GBQualifier_value').nil?
            part[:seq] = get_value(entry, 'GBQualifier_value') 
            break
          end
        end unless quals.nil?
        break unless part[:seq].nil?
      end unless features.nil?
    end

    if part[:seq].nil?
      return {error: "Retrieve #{accession} failed! No sequence data found. Please upload your sequence file instead of using accession number."}
    else
      part[:seq].upcase! 
    end

    return part
  end

  def get_value(hash, *path)
    if hash.class == Hash
      path.inject(hash) { |obj, item| obj[item] || break }
    else
      return nil
    end
  end

end
