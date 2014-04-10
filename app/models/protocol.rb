class Protocol < ActiveRecord::Base
  belongs_to :organism
  belongs_to :lab
  has_many :designs

  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :forbid_enzymes, :ext_suffix, :int_prefix, :int_suffix, :organism, :organism_id, :check_enzymes, :comment, :lab, :lab_id

  validates_presence_of :name

  def steps
    steps = Array.new
    unless organism_id.blank?
      steps << 'Codon Optimization'
    end
    unless forbid_enzymes.blank?
      steps << 'Restriction Enzyme Substraction'
    end
    unless check_enzymes.blank?
      steps << 'Report Enzyme Sites'
    end
    unless ext_suffix.blank? && ext_prefix.blank?
      steps << "Add prefix and/or suffix"
    end
    unless construct_size.blank?
      steps << 'Carve Long Sequence'
    end
    return steps.join(' ---> ')
  end

end
