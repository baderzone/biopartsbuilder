class Organism < ActiveRecord::Base
  has_many :sequence
  attr_accessible :code, :fullname, :name
end
