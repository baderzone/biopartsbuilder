class AddColumnInJobs < ActiveRecord::Migration
  def up
  
     add_column :jobs, :errors, :text
  
  end

  def down
  end
end
