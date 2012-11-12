class Design < ActiveRecord::Base
  belongs_to :part
  belongs_to :protocol
  has_many :construct
  
  attr_accessible :part_id, :protocol_id, :user_id
end
