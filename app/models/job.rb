class Job < ActiveRecord::Base
  belongs_to :job_type
  belongs_to :job_status
  belongs_to :user

  attr_accessible :job_status_id, :job_status, :job_type_id, :job_type, :user_id, :user, :error_info

  def change_status(s)
    self.job_status_id = JobStatus.find_by_name(s).id
    self.save(:validate => false)
  end 

end
