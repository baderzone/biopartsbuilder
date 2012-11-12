class Order < ActiveRecord::Base
  belongs_to :user
  attr_accessible :name, :user_id, :vendor
end
