class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :is_valid_session?

  helper_method :current_user

  private
  def is_valid_session?
    if session[:user_id].nil?
      redirect_to root_url, :flash => { :error => "Login required." }
    end 
  end   

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def get_job_type_id(type_name)
    @job_type = JobType.where("name = ?", type_name)
    @job_type.each do |type|
      return type.id
    end
  end

  def get_job_status_id(status_name)
    @job_status = JobStatus.where("name = ?", status_name)
    @job_status.each do |status|
      return status.id
    end
  end

end
