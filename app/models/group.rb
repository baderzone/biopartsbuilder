class Group < ActiveRecord::Base
  has_many :users
	attr_accessible :description, :name
end
