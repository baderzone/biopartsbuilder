class Design < ActiveRecord::Base
  belongs_to :part
  belongs_to :protocol
  has_many :construct
  
  attr_accessible :part_id, :protocol_id, :construct, :part, :protocol

  validates_presence_of :part_id, :protocol_id

end
