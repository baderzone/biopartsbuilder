class ChangeColumnTypeInProtocol < ActiveRecord::Migration
  def up
    change_column :protocols, :overlap, :text
  end

  def down
  end
end
