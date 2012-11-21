class Construct < ActiveRecord::Base
  belongs_to :design
  attr_accessible :design_id, :name, :seq, :comment
  validates_presence_of :design_id, :name, :seq
end
