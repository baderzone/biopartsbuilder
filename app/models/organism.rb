class Organism < ActiveRecord::Base
  has_many :sequence
  has_many :protocol
  
  attr_accessible :code, :fullname, :name

  validates_presence_of :fullname, :name
end
