require 'date'

namespace :partsBuilder do
  desc 'Utility methods for DB maintance'

  namespace :gff do
    desc 'import GFF into db'

    task :import => :environment do
      filename = ENV['filename']
      genome = ENV['genome']
      gff_created_at = ENV['gff_created_at']
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
      puts "Chromosomes loaded! Start loading annotations"

      #gff_created_at = Date.parse(gff.records[0].to_s).to_s
      gff.records.each do |row|
        if row.start && row.feature != 'chromosome'
          attribute = {'Name' => nil, 'gene' => nil, 'Ontology_term' => nil, 'Note' => nil, 'dbxref' => nil, 'orf_classification' => nil}

          row.attributes.each do |entry|
            key, value = entry
            attribute[key] = value if attribute.has_key?(key)
          end

          chromosome = Chromosome.find_by_name(row.seqname)
          feature = Feature.find_by_name(row.feature) || Feature.create(:name => row.feature)

          case row.strand
          when '+'
            strand = 'W'
          when '-'
            strand = 'C'
          end

          if attribute['Name'].nil? || chromosome.nil?
            puts "Warning: something wrong with this line, didn't load to DB: #{row.to_s}"
          else
            Annotation.create(chromosome: chromosome, start: row.start, end: row.end, feature: feature, strand: strand, systematic_name: attribute['Name'], gene_name: attribute['gene'], ontology_term: attribute['Ontology_term'], dbxref: attribute['dbxref'], description: attribute['Note'], orf_classification: attribute['orf_classification'], gff_created_at: gff_created_at)
          end
        end
      end

    end
  end

  namespace :promoter do
    desc 'create promoters and terminators and store them into db'

    task :create => :environment do
      first = ENV['range'].split(',')[0].to_i
      last = ENV['range'].split(',')[1].to_i
      puts "create promoters and terminators for annotation records from #{first} to #{last}"
      annotations = Annotation.find((first..last).to_a) 
      # create interval tree
      puts "start creating interval trees"
      range_w = Hash.new
      range_c = Hash.new
      annotations.each do |a|
        if a.feature.name == 'gene'
          case a.strand
          when 'W'
            range_w[a.start..a.end] = a.systematic_name
          when 'C'
            range_c[a.start..a.end] = a.systematic_name
          end
        end
      end
      tree_w = SegmentTree.new(range_w)
      tree_c = SegmentTree.new(range_c)
      # create promoters and terminators
      puts "start creating promoters and terminators"
      annotations.each do |a|
        if a.feature.name == 'CDS'
          gene_sys_name = a.systematic_name.split('_')[0]
          gene = Annotation.find_by_systematic_name(gene_sys_name)
          case a.strand
          when 'W'
            p_end = a.start - 1
            p_start = p_end - 499
            p_start = 1 if p_start < 1
            unless tree_w.find(p_start).nil?
              if tree_w.find(p_start).value != gene_sys_name
                p_start = tree_w.find(p_start).range.last + 1
              end
            end
            t_start = a.end + 1
            t_end = t_start + 99
            t_end = a.chromosome.seq.size if t_end > a.chromosome.seq.size
            unless tree_w.find(t_end).nil?
              if tree_w.find(t_end).value != gene_sys_name
                t_end = tree_w.find(t_end).range.begin - 1
              end
            end
          when 'C'
            t_end = a.start - 1
            t_start = t_end - 499
            t_start = 1 if t_start < 1
            unless tree_w.find(t_start).nil?
              if tree_w.find(t_start).value != gene_sys_name
                t_start = tree_w.find(t_start).range.last + 1
              end
            end
            p_start = a.end + 1
            p_end = p_start + 99
            p_end = a.chromosome.seq.size if p_end > a.chromosome.seq.size
            unless tree_w.find(p_end).nil?
              if tree_w.find(p_end).value != gene_sys_name
                p_end = tree_w.find(p_end).range.begin - 1
              end
            end
          end
          # store promoters and terminators
          if (p_end - p_start) + 1 > 10
            Annotation.create(chromosome_id: a.chromosome_id, start: p_start, end: p_end, feature: Feature.find_by_name('promoter'), strand: a.strand, systematic_name: "#{gene_sys_name}_promoter", gene_name: gene.try(:gene_name), gff_created_at: a.gff_created_at)
          end
          if (t_end - t_start) + 1 > 10
            Annotation.create(chromosome_id: a.chromosome_id, start: t_start, end: t_end, feature: Feature.find_by_name('terminator'), strand: a.strand, systematic_name: "#{gene_sys_name}_terminator", gene_name: gene.try(:gene_name), gff_created_at: a.gff_created_at)
          end

          finished_percent = ((a.id - first)/(last - first).to_f)*100
          puts "#{finished_percent}% finished!" if finished_percent % 10 == 0
        end
      end
    end
  end

end

