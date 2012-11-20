class Vendor < ActiveRecord::Base
  has_many :order
  
  attr_accessible :name

   validates :name, :presence => true
end
