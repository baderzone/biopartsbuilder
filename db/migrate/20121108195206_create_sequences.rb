class CreateSequences < ActiveRecord::Migration
  def change
    create_table :sequences do |t|
      t.integer :accession
      t.integer :organism_id
      t.integer :part_id
      t.string :seq
      t.string :annotation

      t.timestamps
    end
  end
end
