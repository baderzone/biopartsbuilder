class AddCommentInDesigns < ActiveRecord::Migration
  def up
    add_column :designs, :comment, :text
  end

  def down
  end
end
