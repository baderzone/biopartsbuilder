class SessionsController < ApplicationController
  skip_before_filter :is_valid_session?
    
  def create
    auth = request.env['omniauth.auth']    
    user = User.find_by_provider_and_email(auth[:provider],auth[:info][:email])
    if user.nil?
      return redirect_to new_lab_path
    end
    session[:user_id] = user.id
    redirect_to root_url, :notice => "Welcome back, #{user.fullname}!"
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_url, :notice => "Logged out!"
  end
  
end
