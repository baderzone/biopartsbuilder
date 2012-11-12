class Part < ActiveRecord::Base
  belongs_to :user
  has_one :sequence
  has_many :design
  
  attr_accessible :name
end
