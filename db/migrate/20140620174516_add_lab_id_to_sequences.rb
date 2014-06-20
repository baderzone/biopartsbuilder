class AddLabIdToSequences < ActiveRecord::Migration
  def change
    add_column :sequences, :lab_id, :integer
    add_index :sequences, :lab_id
  end
end
