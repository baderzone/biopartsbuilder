class Protocol < ActiveRecord::Base
  belongs_to :organism
  has_many :designs
  
  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :forbid_enzymes, :ext_suffix, :int_prefix, :int_suffix, :organism, :organism_id, :check_enzymes, :comment
  
  validates_presence_of :name, :ext_prefix, :ext_suffix, :int_prefix, :int_suffix, :overlap, :construct_size,  :forbid_enzymes, :organism
  
end
