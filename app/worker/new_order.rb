class NewOrder
  @queue = :partsbuilder_new_order_queue

  def self.perform(para)

    require 'csv'

    # change job status
    job = Job.find(para['job_id'])
    job.change_status('running')
    design_id_list = para['designs']

		######################### Main Start ########################
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
		########################## Main End #########################

    job.change_status('finished')
    # send email notice
    order = Order.find(para['order_id'])
    PartsbuilderMailer.finished_notice(order.user, nil).deliver

  end

end
