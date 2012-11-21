class Sequence < ActiveRecord::Base
  belongs_to :organism
  belongs_to :part

  attr_accessible :accession, :annotation, :organism_id, :part_id, :seq

  validates_presence_of :accession
end
