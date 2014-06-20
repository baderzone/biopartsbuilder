class Lab < ActiveRecord::Base
  has_many :users
  has_many :protocols
  has_many :sequences
  has_and_belongs_to_many :parts
  has_and_belongs_to_many :designs
  attr_accessible :description, :name

  def administrators
    admin = Array.new
    users.each do |u|
      if u.group.name == 'admin'
        admin << u.fullname
      end 
    end
    return admin
  end

end
