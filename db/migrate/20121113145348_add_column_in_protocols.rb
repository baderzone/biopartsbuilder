class AddColumnInProtocols < ActiveRecord::Migration
  def up
    add_column :protocols, :organism, :integer
  end

  def down
  end
end
