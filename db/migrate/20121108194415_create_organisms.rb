class CreateOrganisms < ActiveRecord::Migration
  def change
    create_table :organisms do |t|
      t.string :name
      t.string :fullname
      t.integer :code

      t.timestamps
    end
  end
end
