class CreateLabs < ActiveRecord::Migration
  def up
    create_table :labs do |t| 
      t.string :name
      t.text :definition 

      t.timestamps
    end 
  end

  def down
  end
end
