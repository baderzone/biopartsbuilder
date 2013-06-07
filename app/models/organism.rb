class Organism < ActiveRecord::Base
  has_many :sequences
  has_many :protocols
  
  attr_accessible :code, :fullname, :name

  validates_presence_of :fullname, :name
end
