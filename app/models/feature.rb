class Feature < ActiveRecord::Base
  has_many :annotations

  attr_accessible :name, :definition

end
