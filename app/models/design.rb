class Design < ActiveRecord::Base
  belongs_to :part
  belongs_to :protocol
  has_many :constructs
  
  attr_accessible :part_id, :protocol_id, :construct, :part, :protocol, :comment

  validates_presence_of :part_id, :protocol_id

end
