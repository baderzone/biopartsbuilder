class Construct < ActiveRecord::Base
  belongs_to :design
  attr_accessible :design_id, :name, :seq, :comment
end
