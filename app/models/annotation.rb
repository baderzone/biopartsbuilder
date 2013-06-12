class Annotation < ActiveRecord::Base
  belongs_to :feature
  belongs_to :chromosome

  attr_accessible :chromosome_id, :start, :end, :feature_id, :strand, :systematic_name, :gene_name, :ontology_term, :dbxref, :description, :orf_classification, :gff_created_at
  attr_accessible :chromosome, :feature

end
