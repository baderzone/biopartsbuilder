class ChangeColumnsInProtocol < ActiveRecord::Migration
  def up
    add_column :protocols, :ext_prefix, :string
    add_column :protocols, :ext_suffix, :string
    rename_column :protocols, :prefix, :int_prefix
    rename_column :protocols, :suffix, :int_suffix
  end

  def down
  end
end
