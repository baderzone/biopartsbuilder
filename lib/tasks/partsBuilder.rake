require 'date'

namespace :partsBuilder do
  desc 'Utility methods for DB maintance'

  namespace :tire do
    desc 'import elasticsearch indexes'

    task :import => :environment do
      group_size = 1000
      Annotation.find_in_batches(start: 0, batch_size: group_size) do |batch|
        puts "start indexing records #{batch[0].id}~#{batch[-1].id}"
        Tire.index("annotations").import batch
      end
    end
  end

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
      organism = ENV['organism']
      puts "create promoters and terminators for #{organism}"

      org = Organism.find_by_name(organism)
      chrs = Chromosome.find_all_by_organism_id(org.id)
      chr_ids = Array.new
      chrs.each {|c| chr_ids << c.id}
      feature = Feature.find_by_name('CDS')

      for chr_id in chr_ids
        strand = 'W'  
        annotations = Annotation.order('start').find_all_by_chromosome_id_and_feature_id_and_strand(chr_id, feature.id, strand) 

        unless annotations.blank?
          cds_before = nil
          annotations.each do |a|
            if cds_before.nil?  
              p_start = a.start - 500
              p_start = 1 if p_start < 1
              p_end = a.start - 1
              p_name = a.systematic_name.split('_')[0] + '_promoter'
              Annotation.create(chromosome_id: chr_id, start: p_start, end: p_end, feature: Feature.find_by_name('promoter'), strand: strand, systematic_name: p_name, gff_created_at: a.gff_created_at)
              cds_before = {'name' => a.systematic_name.split('_')[0], 'pos' => a.end}

            else
              gap = a.start - cds_before['pos'] - 1
              if gap > 2
                if gap > 100
                  t_end = cds_before['pos'] + 100
                else
                  t_end = a.start - 1
                end
                t_start = cds_before['pos'] + 1
                t_name = cds_before['name'] + '_terminator'
                Annotation.create(chromosome_id: chr_id, start: t_start, end: t_end, feature: Feature.find_by_name('terminator'), strand: strand, systematic_name: t_name, gff_created_at: a.gff_created_at)

                if gap > 500
                  p_start = a.start - 500
                else
                  p_start = cds_before['pos'] + 1
                end
                p_end = a.start - 1
                p_name = a.systematic_name.split('_')[0] + '_promoter'
                Annotation.create(chromosome_id: chr_id, start: p_start, end: p_end, feature: Feature.find_by_name('promoter'), strand: strand, systematic_name: p_name, gff_created_at: a.gff_created_at)
              end
              cds_before = {'name' => a.systematic_name.split('_')[0], 'pos' => a.end}
            end  
          end
          # last CDS
          this_chr = Chromosome.find(annotations[-1].chromosome_id)
          t_end = annotations[-1].end + 100
          t_end = this_chr.seq.size if t_end > this_chr.seq.size
          t_start = annotations[-1].end + 1
          t_name = annotations[-1].systematic_name.split('_')[0] + '_terminator'
          Annotation.create(chromosome_id: annotations[-1].chromosome_id, start: t_start, end: t_end, feature: Feature.find_by_name('terminator'), strand: strand, systematic_name: t_name, gff_created_at: annotations[-1].gff_created_at)
        end

        strand = 'C'  
        annotations = Annotation.order('start').find_all_by_chromosome_id_and_feature_id_and_strand(chr_id, feature.id, strand) 

        unless annotations.blank?
          cds_before = nil
          annotations.each do |a|
            if cds_before.nil?
              t_start = a.start - 100
              t_start = 1 if t_start < 1
              t_end = a.start - 1
              t_name = a.systematic_name.split('_')[0] + '_terminator'
              Annotation.create(chromosome_id: chr_id, start: t_start, end: t_end, feature: Feature.find_by_name('terminator'), strand: strand, systematic_name: t_name, gff_created_at: a.gff_created_at)
              cds_before = {'name' => a.systematic_name.split('_')[0], 'pos' => a.end}

            else
              gap = a.start - cds_before['pos'] - 1
              if gap > 2
                if gap > 500
                  p_end = cds_before['pos'] + 500
                else
                  p_end = a.start - 1
                end
                p_start = cds_before['pos'] + 1
                p_name = cds_before['name'] + '_promoter'
                Annotation.create(chromosome_id: chr_id, start: p_start, end: p_end, feature: Feature.find_by_name('promoter'), strand: strand, systematic_name: p_name, gff_created_at: a.gff_created_at)

                if gap > 100
                  t_start = a.start - 100
                else
                  t_start = cds_before['pos'] + 1
                end
                t_end = a.start - 1
                t_name = a.systematic_name.split('_')[0] + '_terminator'
                Annotation.create(chromosome_id: chr_id, start: t_start, end: t_end, feature: Feature.find_by_name('terminator'), strand: strand, systematic_name: t_name, gff_created_at: a.gff_created_at)
              end
              cds_before = {'name' => a.systematic_name.split('_')[0], 'pos' => a.end}
            end  
          end
          # last CDS
          this_chr = Chromosome.find(annotations[-1].chromosome_id)
          p_end = annotations[-1].end + 500
          p_end = this_chr.seq.size if p_end > this_chr.seq.size
          p_start = annotations[-1].end + 1
          p_name = annotations[-1].systematic_name.split('_')[0] + '_promoter'
          Annotation.create(chromosome_id: annotations[-1].chromosome_id, start: p_start, end: p_end, feature: Feature.find_by_name('promoter'), strand: strand, systematic_name: p_name, gff_created_at: annotations[-1].gff_created_at)
        end

      end
    end
  end

end

