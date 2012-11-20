class Order < ActiveRecord::Base
  belongs_to :user
  belongs_to :vendor
  attr_accessible :name, :user, :user_id, :vendor, :vendor_id
end
