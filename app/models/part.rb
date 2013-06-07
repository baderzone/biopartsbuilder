class Part < ActiveRecord::Base
  belongs_to :user
  has_one :sequence, :autosave => true
  has_many :designs

  attr_accessible :name, :sequence, :comment

  validates_presence_of :name

  def self.find_by_sequence_accession(id)
    seq = Sequence.find_by_accession(id)
    if seq.nil?
      return nil
    else
      part = Part.find(seq.part_id)
      return part
    end
  end

end
