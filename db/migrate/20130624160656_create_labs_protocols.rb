class CreateLabsProtocols < ActiveRecord::Migration
  def up
    create_table :labs_protocols do |t| 
      t.integer :lab_id
      t.integer :protocol_id 

      t.timestamps
    end 
    add_index :labs_protocols, :lab_id
    add_index :labs_protocols, :protocol_id
  end

  def down
  end
end
