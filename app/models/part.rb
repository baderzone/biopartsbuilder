class Part < ActiveRecord::Base
  belongs_to :user
  has_one :sequence, :autosave => true
  has_many :design
  
  attr_accessible :name, :sequence
end
