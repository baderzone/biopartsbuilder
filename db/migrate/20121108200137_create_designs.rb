class CreateDesigns < ActiveRecord::Migration
  def change
    create_table :designs do |t|
      t.integer :part_id
      t.integer :protocol_id
      t.integer :user_id

      t.timestamps
    end
  end
end
