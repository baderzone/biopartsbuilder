class DeleteUserInDesigns < ActiveRecord::Migration
  def up
    remove_column :designs, :user_id
  end

  def down
  end
end
