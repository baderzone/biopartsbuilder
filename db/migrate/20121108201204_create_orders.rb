class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.string :name
      t.integer :user_id
      t.string :vendor

      t.timestamps
    end
  end
end
