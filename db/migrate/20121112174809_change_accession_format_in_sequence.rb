class ChangeAccessionFormatInSequence < ActiveRecord::Migration
  def up
    change_column :sequences, :accession, :string
  end

  def down
  end
end
