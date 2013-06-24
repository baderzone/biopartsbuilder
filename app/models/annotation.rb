class Annotation < ActiveRecord::Base
  include Tire::Model::Search
  include Tire::Model::Callbacks

  belongs_to :feature
  belongs_to :chromosome

  attr_accessible :chromosome_id, :start, :end, :feature_id, :strand, :systematic_name, :gene_name, :ontology_term, :dbxref, :description, :orf_classification, :gff_created_at
  attr_accessible :chromosome, :feature

  mapping do
    indexes :id, :index => :not_analyzed
    indexes :systematic_name, :type => 'string', :analyzer => 'snowball'
    indexes :gene_name, :type => 'string', :analyzer => 'snowball'
    indexes :strand, :type => 'string'
    indexes :ontology_term, :type => 'string', :analyzer => 'snowball'
    indexes :description, :type => 'string', :analyzer => 'english'
    indexes :orf_classification, :type => 'string', :analyzer => 'snowball'
    indexes :start, :type => 'integer'
    indexes :end, :type => 'integer'
    indexes :chromosome, :as => 'chromosome.name'
    indexes :feature, :as => 'feature.name'
    indexes :organism, :as => 'chromosome.organism.fullname'
  end

end
