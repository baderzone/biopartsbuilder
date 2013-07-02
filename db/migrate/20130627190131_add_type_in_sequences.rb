class AddTypeInSequences < ActiveRecord::Migration
  def up
    add_column :sequences, :seq_type, :string
  end

  def down
  end
end
