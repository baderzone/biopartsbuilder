class ChangeSeqTypeInConstructs < ActiveRecord::Migration
  def up
    change_column :constructs, :seq, :text
  end

  def down
  end
end
