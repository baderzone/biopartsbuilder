class RenameErrorColumnInJobs < ActiveRecord::Migration
  def up
  
    rename_column :jobs, :errors, :error_info
  
  end

  def down
  end
end
