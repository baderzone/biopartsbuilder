require 'csv'
require 'bio'

class FastaFile

  def self.check(file)
    f = Bio::FastaFormat.open(file, 'r')
    sequences = Array.new
    errors = Array.new
    f.each do |entry|
      descriptions = entry.definition.split('|')
      if descriptions.size < 3 
        errors << "Format invalid: #{entry.definition}"
      elsif entry.seq.empty?
        errors << "No sequence data for : #{entry.definition}"
      else
        sequences << {'part' => descriptions[0], 'type' => descriptions[1], 'accession' => descriptions[2], 'org' => descriptions[3]||'unknown'}
      end 
    end 
    f.close
    return sequences, errors
  end
end
