class CreateFileConverts < ActiveRecord::Migration
  def change
    create_table :file_converts do |t|
      t.string :name
      t.integer :user_id

      t.timestamps
    end
  end
end
