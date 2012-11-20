class Design < ActiveRecord::Base
  belongs_to :part
  belongs_to :protocol
  has_many :construct
  
  attr_accessible :part_id, :protocol_id, :construct, :part, :protocol

  validates :part_id, :presence => true
  validates :protocol_id, :presence => true

end
