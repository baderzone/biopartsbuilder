class AddColumnsInProtocols < ActiveRecord::Migration
  def up
    add_column :protocols, :check_enzymes, :string
    add_column :protocols, :comment, :text
    rename_column :protocols, :rs_enz, :forbid_enzymes
  end

  def down
  end
end
