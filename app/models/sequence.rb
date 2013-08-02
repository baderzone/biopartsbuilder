class Sequence < ActiveRecord::Base
  include Tire::Model::Search
  include Tire::Model::Callbacks
  
  belongs_to :organism
  belongs_to :part

  attr_accessible :accession, :annotation, :organism_id, :part_id, :seq, :organism, :seq_type

  validates_presence_of :accession

  mapping do
    indexes :id, :index => :not_analyzed
    indexes :part_id, :index => :not_analyzed
    indexes :name, :as => 'part.name', :type => 'string', :analyzer => 'snowball'
    indexes :accession_number, :as => 'accession', :type => 'string', :analyzer => 'snowball'
    indexes :organism, :as => "organism.try(:fullname)", :type => 'string', :analyzer => 'snowball'
    indexes :sequence, :as => 'seq', :type => 'string', :analyzer => 'snowball'
    indexes :feature, :as => 'annotation', :type => 'string', :analyzer => 'snowball'
  end

end
