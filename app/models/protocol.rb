class Protocol < ActiveRecord::Base
  belongs_to :organism
  belongs_to :lab
  has_many :designs
  
  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :forbid_enzymes, :ext_suffix, :int_prefix, :int_suffix, :organism, :organism_id, :check_enzymes, :comment, :lab, :lab_id
  
  validates_presence_of :name
  
end
