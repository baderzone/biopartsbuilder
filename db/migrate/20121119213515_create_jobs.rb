class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.integer :job_type_id
      t.integer :job_status_id
      t.integer :job_user_id

      t.timestamps
    end
  end
end
