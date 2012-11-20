class ChangeOrders < ActiveRecord::Migration
  def up
    change_column :orders, :vendor, :integer
    rename_column :orders, :vendor, :vendor_id
  end

  def down
  end
end
