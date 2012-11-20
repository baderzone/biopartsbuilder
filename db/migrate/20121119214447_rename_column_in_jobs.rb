class RenameColumnInJobs < ActiveRecord::Migration
  def up
  
    rename_column :jobs, :job_user_id, :user_id

  end

  def down
  end
end
