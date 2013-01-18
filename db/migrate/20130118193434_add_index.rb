class AddIndex < ActiveRecord::Migration
  def up
    add_index :constructs, :design_id
		add_index :designs, :part_id
		add_index :designs, :protocol_id
		add_index :jobs, :job_type_id
		add_index :jobs, :job_status_id
		add_index :jobs, :user_id
		add_index :orders, :user_id
    add_index :orders, :vendor_id
		add_index :protocols, :organism_id
		add_index :sequences, :organism_id
		add_index :sequences, :part_id
	end

  def down
  end
end
