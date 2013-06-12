class CreateAnnotations < ActiveRecord::Migration
  def up
    create_table :annotations do |t| 
      t.integer :chromosome_id
      t.integer :start
      t.integer :end
      t.integer :feature_id
      t.string :strand
      t.string :systematic_name
      t.string :gene_name
      t.string :ontology_term
      t.string :dbxref
      t.text :description
      t.string :orf_classification
      t.date :gff_created_at

      t.timestamps
    end 
  end

  def down
  end
end
