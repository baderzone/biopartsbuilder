class Order < ActiveRecord::Base
  belongs_to :user
  belongs_to :vendor
  has_and_belongs_to_many :designs

  attr_accessible :name, :user, :user_id, :vendor, :vendor_id, :design_ids

  validates_presence_of :name, :vendor_id
end
