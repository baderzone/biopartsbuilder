class CreateChromosomes < ActiveRecord::Migration
  def up
    create_table :chromosomes do |t| 
      t.string :name
      t.integer :organism_id
      t.text :seq
      t.string :genome_version

      t.timestamps
    end 
  end

  def down
  end
end
