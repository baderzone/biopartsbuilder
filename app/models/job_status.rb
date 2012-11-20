class JobStatus < ActiveRecord::Base
  has_many :job
  
  attr_accessible :name
end
