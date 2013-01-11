class AddColumnToUsers < ActiveRecord::Migration
  def self.up
		add_column :users, :group_id, :integer
  end
end
