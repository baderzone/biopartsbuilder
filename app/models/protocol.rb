class Protocol < ActiveRecord::Base
  belongs_to :organism
  has_many :design
  
  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :forbid_enzymes, :ext_suffix, :int_prefix, :int_suffix, :organism, :organism_id, :check_enzymes, :comment
  
  validates :name, :presence => true
  validates :ext_prefix, :presence => true
  validates :ext_suffix, :presence => true
  validates :int_prefix, :presence => true
  validates :int_suffix, :presence => true
  validates :overlap, :presence => true
  validates :construct_size, :presence => true
  validates :forbid_enzymes, :presence => true
  validates :organism, :presence => true

end
