class NewPart
	@queue = :partsbuilder_new_part_queue

	def self.perform(para)

		require 'xmlsimple' 
		Bio::NCBI.default_email = 'synbio@jhu.edu'

		# change job status
		job = Job.find(para['job_id'])
		job.change_status('running')
		error_info = String.new
		is_new_part_success = true

		################### Main Start #################
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
				if is_new_part_success && (Sequence.find_by_accession(accession).nil?)
					if ! org_name.empty?
						organism = Organism.find_by_fullname(org_name) || Organism.create(:fullname => org_name, :name => org_abbr)
						organism_id = organism.id
					end
					part = Part.create(:name => part_name)
					Sequence.create(:accession => accession, :organism_id => organism_id, :part_id => part.id, :seq => seq, :annotation => "CDS")

					# create protein fasta file for GeneDesign
					fasta_seq = Bio::Sequence.new(seq)
					f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{accession}.fasta", 'w')
					f.print fasta_seq.output(:fasta, :header => part_name, :width => 80)
					f.close
				end
				# end of retrieving one sequence from FASTA file 
			end
			# if a list of accession numbers submitted instead of a FASTA file
		else
			accession_list = para['accession']
			accession_list.each do |accession|
				accession.strip!
				if (! accession.empty?) && (Sequence.find_by_accession(accession).nil?) && is_new_part_success
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
		################### Main End #################

		# change job status
		if is_new_part_success
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
