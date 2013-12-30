require 'xmlsimple'

class BioPart

  def retrieve(input, type)
    bioparts = Array.new
    error = String.new

    case type
    when 'genome'
      input.each do |entry|
        biopart = create_from_genome(entry)
        if biopart[:error].nil?
          bioparts << biopart
        else
          error = biopart[:error]
          return bioparts, error
        end
      end
    when 'fasta'
      in_file = Bio::FastaFormat.open(input, 'r')
      in_file.each do |entry|
        biopart = create_from_fasta(entry)
        bioparts << biopart
      end 
      in_file.close
    when 'ncbi'
      input.each do |entry|
        sequence = Sequence.find_all_by_accession(entry).try(:first)
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
          part = sequence.part
          bioparts << {name: part.name, type: sequence.annotation, protein_seq: part.protein_seq.try(:seq), dna_seq: part.dna_seq.try(:seq), accession_num: sequence.accession, org_latin: sequence.organism.fullname, org_abbr: sequence.organism.name, comment: part.comment} 
        end 
      end 
    end

    return bioparts, error 
  end

  def check(bioparts)
    error = String.new
    bioparts.each do |entry|
      if entry[:dna_seq].nil?
        seq_type = 'protein'
        part_seq = entry[:protein_seq] 
      else
        seq_type = 'dna'
        part_seq = entry[:dna_seq]
      end

      exist_seq = Sequence.find_by_accession_and_seq_type(entry[:accession_num], seq_type)
      if !exist_seq.nil?
        if exist_seq.seq.upcase != part_seq.upcase
          error = "Part '#{entry[:accession_num]}' with different sequence found!  Please check if the data is correct. Accession number must be unique (one sequence, one number). The sequence of part found in the database is: #{exist_seq.seq}. The sequence of your part is: #{part_seq}"
          return error
        end
      end
    end

    return error
  end

  def store(bioparts, user_id)
    part_ids = Array.new
    user = User.find(user_id)
    lab_id = [user.lab.id]

    bioparts.each do |entry|
      if ! entry[:org_latin].nil?
        organism = Organism.find_by_fullname(entry[:org_latin],) || Organism.create(:fullname => entry[:org_latin], :name => entry[:org_abbr])
      end
      sequence = Sequence.find_all_by_accession(entry[:accession_num]).try(:first)
      if sequence.blank?
        part = Part.create(:name => entry[:name].gsub(/__/, '_'), :comment => entry[:comment], :lab_ids => lab_id)
        part_ids << part.id

        unless entry[:protein_seq].nil?
          part.sequences.create(:accession => entry[:accession_num], :organism => organism, :seq => entry[:protein_seq].upcase, :annotation => entry[:type], :seq_type => 'protein')
        end
        unless entry[:dna_seq].nil?
          part.sequences.create(:accession => entry[:accession_num], :organism => organism, :seq => entry[:dna_seq].upcase, :annotation => entry[:type], :seq_type => 'dna')
        end

        # create fasta file for GeneDesign
        unless entry[:protein_seq].nil?
          fasta_seq = Bio::Sequence.new(entry[:protein_seq])
          f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{part.id}_protein.fasta", 'w')
          f.print fasta_seq.output(:fasta, :header => part.name, :width => 80)
          f.close
        end
        unless entry[:dna_seq].nil?
          fasta_seq = Bio::Sequence.new(entry[:dna_seq])
          f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{part.id}_dna.fasta", 'w')
          f.print fasta_seq.output(:fasta, :header => part.name, :width => 80)
          f.close
        end
      else
        part = sequence.part
        part.lab_ids = (part.lab_ids + lab_id).uniq
        part.save
        part_ids << part.id
      end
    end

    return part_ids
  end


  private
  def create_from_genome(input)
    annotation = Annotation.find(input)

    org = annotation.chromosome.organism.name
    comment = annotation.description 
    #get part name
    accession = annotation.systematic_name
    if annotation.gene_name.blank?
      if annotation.feature.name == 'CDS' && org == 'Sce'
        accession = annotation.systematic_name.chomp('_CDS')
        gene = Annotation.find_by_systematic_name(accession)
        comment = gene.description
        gene_name = gene.try(:gene_name)
        if !gene_name.blank? && gene_name != accession
          part_name = "#{annotation.feature.name}_#{org}_#{gene_name}_#{accession}"
        else
          part_name = "#{annotation.feature.name}_#{org}_#{accession}"
        end
      else
        part_name = "#{annotation.feature.name}_#{org}_#{annotation.systematic_name}"
      end
    else
      part_name = "#{annotation.feature.name}_#{org}_#{annotation.gene_name}_#{annotation.systematic_name}"
    end 
    # get sequence
    if annotation.strand == 'W'
      dna_sequence = annotation.chromosome.seq[(annotation.start-1)..(annotation.end-1)]
    else
      chr_seq = Bio::Sequence::NA.new(annotation.chromosome.seq).complement
      dna_sequence = chr_seq[(chr_seq.size - annotation.end)..(chr_seq.size - annotation.start)]
    end
    return {error: "Sequence of #{accession} not found!"} if dna_sequence.blank?
    #translation
    if annotation.feature.name == 'CDS'
      protein_sequence = Bio::Sequence::NA.new(dna_sequence).translate
      protein_sequence.chomp!('*')
      return {error: "Translation of #{accession} failed!"} if protein_sequence.include?('*')
    else
      protein_sequence = nil
    end

    part = {name: part_name, type: annotation.feature.name, protein_seq: protein_sequence, dna_seq: dna_sequence, accession_num: accession, org_latin: annotation.chromosome.organism.fullname, org_abbr: annotation.chromosome.organism.name, comment: comment}
    return part
  end

  def create_from_fasta(entry)
    part = {name: nil, type: nil, seq: nil, accession_num: nil, org_latin: nil, org_abbr: nil, comment: nil}
    descriptions = entry.definition.split('|')
    gene_name = descriptions[0].strip.split(' ').join('-')

    part[:type] = descriptions[1].strip
    part[:accession_num] = descriptions[2].strip
    unless descriptions[3].blank?
      part[:org_latin] = descriptions[3].strip
      part[:org_abbr] = part[:org_latin].split(' ')[0][0].upcase + part[:org_latin].split(' ')[1][0, 2].downcase 
    end
    part[:comment] = descriptions[4] && descriptions[4].strip
    part[:name] = "#{part[:type]}_#{part[:org_abbr]}_#{gene_name}_#{part[:accession_num]}"
    sequence = Bio::Sequence.auto(entry.seq)
    if sequence.moltype == Bio::Sequence::AA 
      part[:protein_seq] = entry.seq
    else
      part[:dna_seq] = entry.seq
    end
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
      part[:protein_seq] = get_value(xml, 'GBSeq', 'GBSeq_sequence') 
      part[:dna_seq] = nil
    else
      part[:dna_seq] = get_value(xml, 'GBSeq', 'GBSeq_sequence')
      features.each do |f|
        quals = get_value(f, 'GBFeature_quals', 'GBQualifier')
        quals.each do |entry|
          if get_value(entry, 'GBQualifier_name') == "translation" && !get_value(entry, 'GBQualifier_value').nil?
            part[:protein_seq] = get_value(entry, 'GBQualifier_value') 
            break
          end
        end unless quals.nil?
        break unless part[:protein_seq].nil?
      end unless features.nil?
    end

    if part[:protein_seq].nil?
      return {error: "Retrieve #{accession} failed! No sequence data found. Please upload your sequence file instead of using accession number."}
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
