class User < ActiveRecord::Base
  has_many :order
  has_many :job

  attr_accessible :email, :fullname, :provider, :uid, :order, :job

  #utility method for creating an user at the first login
  def self.create_with_omniauth(auth)
    create! do |user|
      user.uid = auth[:uid]
      user.fullname = auth[:info][:name]
      user.email = auth[:info][:email]
      user.provider = auth[:provider]
    end 
  end 
end
