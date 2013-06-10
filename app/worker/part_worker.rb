require 'csv'

class PartWorker
  include Sidekiq::Worker

  def perform(params)

    # change job status
    job = Job.find(params['job_id'])
    job.change_status('running')
    error_info = String.new
    is_new_part_success = true

    # retrieve parts
    bioparts = Array.new
    if !params['seq_file'].nil?
      in_file = Bio::FastaFormat.open(params['seq_file'], 'r')
      in_file.each do |entry|
        biopart = BioPart.new(entry, 'fasta').to_s
        bioparts << biopart
      end
      in_file.close

    else
      params['accessions'].each do |entry|
        if Sequence.find_by_accession(entry).nil?
          biopart = BioPart.new(entry, 'accession').to_s
          if biopart[:error].nil?
            bioparts << biopart
          else
            is_new_part_success = false
            error_info = biopart[:error]
            break
          end
        end
      end
    end

    # check parts
    if is_new_part_success
      bioparts.each do |entry|
        exist_seq = Sequence.find_by_accession(entry[:accession_num])
        if !exist_seq.nil?
          if exist_seq.seq != entry[:seq]
            error_info = "Part '#{entry[:accession_num]}' with different sequence found!  Please check if the data is correct. The sequence of part found in the database is: #{exist_seq.seq}. The sequence of your part is: #{entry[:seq]}"
            is_new_part_success = false
            break
          end
        end
      end
    end

    # store parts
    if is_new_part_success
      bioparts.each do |entry|
        if ! entry[:org_latin].nil?
          organism = Organism.find_by_fullname(entry[:org_latin],) || Organism.create(:fullname => entry[:org_latin], :name => entry[:org_abbr])
        end
        part = Part.create(:name => entry[:name].gsub(/__/, '_'), :comment => entry[:comment])
        part.create_sequence(:accession => entry[:accession_num], :organism => organism, :seq => entry[:seq], :annotation => entry[:type])

        # create protein fasta file for GeneDesign
        fasta_seq = Bio::Sequence.new(entry[:seq])
        f = File.new("#{PARTSBUILDER_CONFIG['program']['part_fasta_path']}/#{entry[:accession_num]}.fasta", 'w')
        f.print fasta_seq.output(:fasta, :header => part.name, :width => 80)
        f.close
      end
    end

    # change job status
    if is_new_part_success
      job.change_status('finished')
    else
      job.change_status('failed')
      job.error_info = error_info
      job.save
    end
    # send email notice
    current_user = User.find(params['user_id'])
    PartsbuilderMailer.finished_notice(current_user, error_info).deliver
  end

end
