class CreateDesignsOrders < ActiveRecord::Migration
  def up
    create_table :designs_orders do |t| 
      t.integer :order_id
      t.integer :design_id 

      t.timestamps
    end 
    add_index :designs_orders, :design_id
    add_index :designs_orders, :order_id
  end

  def down
  end
end
