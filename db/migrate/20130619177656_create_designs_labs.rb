class CreateDesignsLabs < ActiveRecord::Migration
  def up
    create_table :designs_labs do |t| 
      t.integer :lab_id
      t.integer :design_id 

      t.timestamps
    end 
    add_index :designs_labs, :lab_id
    add_index :designs_labs, :design_id
  end

  def down
  end
end
