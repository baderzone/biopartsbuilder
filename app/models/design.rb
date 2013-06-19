class Design < ActiveRecord::Base
  belongs_to :part
  belongs_to :protocol
  has_many :constructs, :dependent => :destroy
  has_and_belongs_to_many :lab
  
  accepts_nested_attributes_for :constructs

  attr_accessible :part_id, :protocol_id, :construct, :part, :protocol, :comment, :lab_ids

  validates_presence_of :part_id, :protocol_id

end
