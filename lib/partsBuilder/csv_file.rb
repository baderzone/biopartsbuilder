require 'csv'
require 'bio'

class CsvFile

  def self.check(file)
    sequences = Array.new
    errors = Array.new
    CSV.foreach(file) do |row|
      unless ['part symbol', 'symbol', 'name'].include?(row[0].downcase)
        if row[0].blank? || row[1].blank? || row[2].blank? || row[4].blank?
          errors << "Something is missing, a part must have symbol, type, accession number and sequence"
        elsif !row[3].blank? and row[3].split(' ').size != 2
          errors << "Wrong organism name '#{row[3]}', must use latin name" 
        else
          sequences << {'part' => row[0].split(' ').join('-'), 'type' => row[1], 'accession' => row[2], 'org' => row[3]||'unknown'}
        end
      end
    end
    return sequences, errors
  end

end
