class ChangeSeqTypeInSequences < ActiveRecord::Migration
  def up
    change_column :sequences, :seq, :text
  end

  def down
  end
end
