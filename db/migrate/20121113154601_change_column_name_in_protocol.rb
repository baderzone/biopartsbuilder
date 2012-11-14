class ChangeColumnNameInProtocol < ActiveRecord::Migration
  def up
    rename_column :protocols, :organism, :organism_id
  end

  def down
  end
end
