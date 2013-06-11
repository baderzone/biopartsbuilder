require 'csv'

class BioOrder
  
  def self.store(path, order_id, design_ids)
    # parameters
    order_path = "#{path}/#{order_id}"
    system "mkdir #{order_path}"

    zip_file_name = "order#{order_id}.zip"
    csv_file_name = "order#{order_id}_all.csv"
    seq_file_name = "order#{order_id}_seq.fasta"
    sum_file_name = "order#{order_id}_summary.txt"

    csv_file = CSV.open("#{order_path}/#{csv_file_name}", 'w')
    seq_file = File.new("#{order_path}/#{seq_file_name}", 'w')
    sum_file = File.new("#{order_path}/#{sum_file_name}", 'w')

    csv_file << ["Part Name", "Length", "Comment", "Part Sequence"]
    total_parts = 0 
    total_bp = 0 

    # write designs to files
    design_ids.each do |design_id|
      design = Design.find(design_id)

      design.constructs.each do |construct|
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

    Zip::ZipFile.open("#{order_path}/#{zip_file_name}", Zip::ZipFile::CREATE) do |ar|
      ar.add(csv_file_name, "#{order_path}/#{csv_file_name}")
      ar.add(seq_file_name, "#{order_path}/#{seq_file_name}")
      ar.add(sum_file_name, "#{order_path}/#{sum_file_name}")
    end
    
   return "#{order_path}/#{zip_file_name}"
  end

end
