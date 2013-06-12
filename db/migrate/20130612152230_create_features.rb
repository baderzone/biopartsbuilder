class CreateFeatures < ActiveRecord::Migration
  def up
    create_table :features do |t| 
      t.string :name
      t.text :definition 

      t.timestamps
    end 
  end

  def down
  end
end
