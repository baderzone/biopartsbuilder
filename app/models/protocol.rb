class Protocol < ActiveRecord::Base
  has_many :design
  
  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :rs_enz, :ext_suffix, :int_prefix, :int_suffix
  
  validates :name, :presence => true
  validates :ext_prefix, :presence => true
  validates :ext_suffix, :presence => true
  validates :int_prefix, :presence => true
  validates :int_suffix, :presence => true
  validates :overlap, :presence => true
  validates :construct_size, :presence => true
  validates :rs_enz, :presence => true
end
