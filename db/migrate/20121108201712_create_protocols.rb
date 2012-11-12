class CreateProtocols < ActiveRecord::Migration
  def change
    create_table :protocols do |t|
      t.string :name
      t.string :prefix
      t.string :suffix
      t.string :overlap
      t.integer :construct_size
      t.string :rs_enz

      t.timestamps
    end
  end
end
