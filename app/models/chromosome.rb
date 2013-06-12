class Chromosome < ActiveRecord::Base
  belongs_to :organism
  has_many :annotations, :dependent => :destroy

  accepts_nested_attributes_for :annotations

  attr_accessible :organism_id, :name, :seq, :genome_version
  attr_accessible :organism

end
