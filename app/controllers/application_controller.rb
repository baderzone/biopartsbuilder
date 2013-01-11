class ApplicationController < ActionController::Base
	protect_from_forgery

	before_filter :is_valid_session?

	helper_method :current_user

	rescue_from CanCan::AccessDenied do |exception|
		redirect_to root_url, :flash => {:error => "You are not allowed to perform this operation!"}
	end

	private
	def is_valid_session?
		if session[:user_id].nil?
			redirect_to root_url, :flash => { :error => "Login required." }
		end 
	end   

	def current_user
		@current_user ||= User.find(session[:user_id]) if session[:user_id]
	end

end
