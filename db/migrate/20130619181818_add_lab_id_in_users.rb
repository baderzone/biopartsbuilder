class AddLabIdInUsers < ActiveRecord::Migration
  def up
    add_column :users, :lab_id, :integer
    add_index :users, :lab_id
  end

  def down
  end
end
