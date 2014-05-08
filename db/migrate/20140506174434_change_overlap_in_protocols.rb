class ChangeOverlapInProtocols < ActiveRecord::Migration
  def up
    rename_column :protocols, :overlap, :overlap_list
    add_column :protocols, :overlap_size, :integer
  end

  def down
  end
end
