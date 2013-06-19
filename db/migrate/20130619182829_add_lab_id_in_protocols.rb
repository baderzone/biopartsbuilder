class AddLabIdInProtocols < ActiveRecord::Migration
  def up
    add_column :protocols, :lab_id, :integer
    add_index :protocols, :lab_id
  end

  def down
  end
end
