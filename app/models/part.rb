class Part < ActiveRecord::Base
  belongs_to :user
  has_many :sequences, :autosave => true
  has_many :designs
  has_and_belongs_to_many :labs

  accepts_nested_attributes_for :sequences

  attr_accessible :name, :sequence_ids, :type, :comment, :lab_ids

  validates_presence_of :name

  def protein_seq
    sequences.each do |seq|
      if seq.seq_type == 'protein'
        return seq
      end
    end
    return nil
  end

  def dna_seq
    sequences.each do |seq|
      if seq.seq_type == 'dna'
        return seq
      end
    end
    return nil
  end

end
