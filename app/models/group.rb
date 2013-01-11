class Group < ActiveRecord::Base
  has_many :user
	attr_accessible :description, :name
end
