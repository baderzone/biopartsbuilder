class CreateLabsParts < ActiveRecord::Migration
  def up
    create_table :labs_parts do |t| 
      t.integer :lab_id
      t.integer :part_id 

      t.timestamps
    end 
    add_index :labs_parts, :lab_id
    add_index :labs_parts, :part_id
  end

  def down
  end
end
