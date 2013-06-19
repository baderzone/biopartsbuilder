class Lab < ActiveRecord::Base
  has_many :users
  has_many :protocols
  has_and_belongs_to_many :parts
  has_and_belongs_to_many :designs
	attr_accessible :description, :name
end
