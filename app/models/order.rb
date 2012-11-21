class Order < ActiveRecord::Base
  belongs_to :user
  belongs_to :vendor
  
  attr_accessible :name, :user, :user_id, :vendor, :vendor_id

  validates_presence_of :name, :vendor_id
end
