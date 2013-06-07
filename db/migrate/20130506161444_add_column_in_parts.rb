class AddColumnInParts < ActiveRecord::Migration
  def up
    add_column :parts, :comment, :text
  end

  def down
  end
end
