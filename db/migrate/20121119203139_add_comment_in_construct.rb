class AddCommentInConstruct < ActiveRecord::Migration
  def up
    add_column :constructs, :comment, :text
  end

  def down
  end
end
