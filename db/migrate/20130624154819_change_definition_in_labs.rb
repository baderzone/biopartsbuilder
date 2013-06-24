class ChangeDefinitionInLabs < ActiveRecord::Migration
  def up
    rename_column :labs, :definition, :description
  end

  def down
  end
end
