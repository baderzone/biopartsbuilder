class Vendor < ActiveRecord::Base
  has_many :orders

  attr_accessible :name

  validates :name, :presence => true
end
