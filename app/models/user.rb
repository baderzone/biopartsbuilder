class User < ActiveRecord::Base

	belongs_to :group
	has_many :orders
	has_many :jobs

	attr_accessible :email, :fullname, :provider, :uid, :group_id
	attr_accessible :order, :job, :group

	validates_presence_of :email

	#utility method for creating an user at the first login
	def self.create_with_omniauth(auth)
		create! do |user|
			user.uid = auth[:uid]
			user.fullname = auth[:info][:name]
			user.email = auth[:info][:email]
			user.provider = auth[:provider]
			user.group_id = Group.find_by_name('user').id 
		end
	end 

end
