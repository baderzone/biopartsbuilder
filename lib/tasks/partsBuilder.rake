require 'date'

namespace :partsBuilder do
  desc 'Utility methods for DB maintance'

  namespace :gff do
    desc 'import GFF into db'

    task :import => :environment do
      filename = ENV['filename']
      genome = ENV['genome']
      puts "Loading annotations from: #{filename}"

      gff = Bio::GFF::GFF3.new(File.open(filename))

      organism_name = genome.split(' ')[0, 2].join(' ')
      organism = Organism.find_by_fullname(organism_name)

      gff.sequences.each do |seq|
        chr = Chromosome.find_by_name_and_organism_id(seq.entry_id, organism.id)
        if chr
          chr.destroy
        end
        Chromosome.create(name: seq.entry_id, organism: organism, seq: seq.to_s, genome_version: genome)
      end

      gff_created_at = Date.parse(gff.records[0].to_s).to_s
      gff.records.each do |row|
        if row.start && row.feature != 'chromosome'
          attribute = {'Name' => nil, 'gene' => nil, 'Ontology_term' => nil, 'Note' => nil, 'dbxref' => nil, 'orf_classification' => nil}

          row.attributes.each do |entry|
            key, value = entry
            attribute[key] = value if attribute.has_key?(key)
          end

          chromosome = Chromosome.find_by_name(row.seqname)
          feature = Feature.find_by_name(row.feature)

          if attribute['Name'].nil? || chromosome.nil? || feature.nil?
            puts "Warning: something wrong with this line, didn't load to DB: #{row.to_s}"
          else
            Annotation.create(chromosome: chromosome, start: row.start, end: row.end, feature: feature, strand: row.strand, systematic_name: attribute['Name'], gene_name: attribute['gene'], ontology_term: attribute['Ontology_term'], dbxref: attribute['dbxref'], description: attribute['Note'], orf_classification: attribute['orf_classification'], gff_created_at: gff_created_at)
          end
        end
      end

    end
  end
end

