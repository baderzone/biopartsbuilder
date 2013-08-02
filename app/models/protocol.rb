class Protocol < ActiveRecord::Base
  belongs_to :organism
  belongs_to :lab
  has_many :designs

  attr_accessible :construct_size, :name, :overlap, :ext_prefix, :forbid_enzymes, :ext_suffix, :int_prefix, :int_suffix, :organism, :organism_id, :check_enzymes, :comment, :lab, :lab_id

  validates_presence_of :name

  def steps
    steps = Array.new
    unless organism_id.nil?
      steps << 'Codon Optimization'
    end
    unless forbid_enzymes.empty?
      steps << 'Restriction Enzyme Substraction'
    end
    unless check_enzymes.empty?
      steps << 'Report Enzyme Sites'
    end
    unless ext_suffix.empty? && ext_prefix.empty?
      steps << "Add prefix and/or suffix"
    end
    unless construct_size.nil?
      steps << 'Carve Long Sequence'
    end
    return steps.join(' ---> ')
  end

end
