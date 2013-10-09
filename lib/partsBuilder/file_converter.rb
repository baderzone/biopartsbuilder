require 'bio'
require 'axlsx'

class FileConverter
  def convert(input, converter_id, output_types)
    output_path = "#{PARTSBUILDER_CONFIG['program']['converter_path']}/#{converter_id}"
    system "mkdir #{output_path}"
    file_list = []

    if input['type'] == 'fasta'
      fasta = create_fasta_from_fasta(input['file'], output_path)
    end

    if output_types.include?('fasta')
      file_list << fasta
    end

    if output_types.include?('xls')
      xls = create_xls(fasta, output_path)
      file_list << xls
    end

    if output_types.include?('sum')
      sum = create_sum(fasta, output_path)
      file_list << sum
    end

    create_zip(file_list, output_path)
  end

  private
  def create_fasta_from_fasta(input, output_path)
    # fix the windows newline incompatible issue
    in_f = File.open(input, 'r')
    tmp_fn = "#{output_path}/tmp.fasta"
    tmp_f = File.new(tmp_fn, 'w')
    in_f.each_line do |l|
      tmp_f.puts l.strip.gsub(/[\r\n]/, "\n")
    end
    in_f.close
    tmp_f.close

    out_fn = "#{output_path}/parts.fasta"
    out_f = File.new("#{output_path}/parts.fasta", 'w')
    parts = {}
    Bio::FastaFormat.open(tmp_fn).each do |e|
      parts[e.entry_id] = e.seq
    end
    parts.each do |k, v|
      out_f.puts Bio::Sequence.new(v).output(:fasta, :header => k, :width => 80)
    end
    out_f.close

    return out_fn
  end

  def create_xls(input, output_path)
    p = Axlsx::Package.new
    ws = p.workbook.add_worksheet(:name => 'Gene Synthesis')
    header = ws.styles.add_style(:b => true)
    ws.add_row ['Gene Name', 'Sequence for Synthesis', 'Length[Bases]'], :style => header

    Bio::FastaFormat.open(input).each do |e|
      ws.add_row [e.entry_id.split(' ')[0], e.seq, e.length]  
    end

    filename = "#{output_path}/parts.xlsx"
    p.serialize(filename)
    return filename
  end

  def create_sum(input, output_path)
    filename = "#{output_path}/summary.txt"
    out_f = File.new(filename, 'w')
    gene_num = 0
    bp = 0

    Bio::FastaFormat.open(input).each do |e|
      gene_num += 1
      bp += e.length
    end
    out_f.puts "Total Parts made: #{gene_num}"
    out_f.puts "Total bp to be Synthesized: #{bp}"
    out_f.close

    return filename
  end

  def create_zip(file_list, output_path)
    Zip::ZipFile.open("#{output_path}/parts.zip", Zip::ZipFile::CREATE) do |ar|
      file_list.each do |f|
        ar.add(f.split('/')[-1], f)
      end
    end
    file_list.each do |f|
      system "rm #{f}"
    end
  end

end
