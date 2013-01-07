class NewPart
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
					ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"protein", "rettype"=>"fasta"})
					if ncbi.include?("Cannot process")
						error_info << "Bad ID: #{accession}! "
						is_ncbi_success = false
					end
				rescue
					error_info << "Retrieve #{accession} failed! "
					is_ncbi_success = false
				end    

				if is_ncbi_success
					# set initial value for variables that will be stored in the database
					geneName = String.new
					seq = String.new
					org_name = ""
					org_abbr = ""
					organism_id = nil
					is_CDS_uniq = true

					# check accession number type, protein or nucleotide
					ncbi_fasta = Bio::FastaFormat.new(ncbi)
					ncbi_seq = Bio::Sequence.auto(ncbi_fasta.seq)
					if ncbi_seq.moltype == Bio::Sequence::NA

						# when nucleotide
						begin
							ncbi = Bio::NCBI::REST.efetch(accession, {"db"=>"nucleotide", "rettype"=>"gb", "retmode" => "xml"})
						rescue
							error_info << "Retrieve #{accession} failed! "
							is_ncbi_success = false
						end

						# retrieve data from xml
						if is_ncbi_success
							xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
							# get organism
							if ! xml['GBSeq']['GBSeq_organism'].nil?
								org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
								org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
							end
							# get gene name and sequence	
							cds_num = 0
							if xml['GBSeq'].has_key?('GBSeq_feature-table') && xml['GBSeq']['GBSeq_feature-table'].has_key?('GBFeature')  
								xml['GBSeq']['GBSeq_feature-table']['GBFeature'].each do |entry|
									if entry.class == Hash && entry.has_value?("CDS")
										cds_num += 1
										# if has more than one CDS, rejected
										if cds_num > 1
											error_info << "Rejected: Requested accession #{accession} contains >1 CDS! "
											is_CDS_uniq = false
											break
										end
										if entry.has_key?('GBFeature_quals') && entry['GBFeature_quals'].has_key?('GBQualifier')
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
						rescue
							error_info << "Retrieve #{accession} failed! "
							is_ncbi_success = false
						end

						# retrieve data from xml
						if is_ncbi_success
							xml = XmlSimple.xml_in(ncbi, {'ForceArray' => false})
							# get organism
							if ! xml['GBSeq']['GBSeq_organism'].nil?
								org_name = xml['GBSeq']['GBSeq_organism'].split(' ')[0,2].join(' ').capitalize
								org_abbr = org_name.split(' ')[0][0] + org_name.split(' ')[1][0,2]
							end
							# get gene name and sequence	
							seq = ncbi_fasta.seq.upcase
							if xml['GBSeq'].has_key?('GBSeq_feature-table') && xml['GBSeq']['GBSeq_feature-table'].has_key?('GBFeature')
								xml['GBSeq']['GBSeq_feature-table']['GBFeature'].each do |entry|
									if entry.has_key?("GBFeature_quals") && entry["GBFeature_quals"].has_key?("GBQualifier")
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
					if seq.empty?
						error_info << "Retrieve #{accession} failed! "
					else
						if is_CDS_uniq
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
