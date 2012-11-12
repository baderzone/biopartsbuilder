class CreateConstructs < ActiveRecord::Migration
  def change
    create_table :constructs do |t|
      t.integer :design_id
      t.string :name
      t.string :seq

      t.timestamps
    end
  end
end
