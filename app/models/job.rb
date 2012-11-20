class Job < ActiveRecord::Base
  belongs_to :job_type
  belongs_to :job_status
  belongs_to :user
  
  attr_accessible :job_status_id, :job_status, :job_type_id, :job_typ, :user_id, :user

end
